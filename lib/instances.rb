#!/usr/bin/env ruby
require 'optparse'
require 'colored'
require_relative 'vominator/constants'
require_relative 'vominator/aws'
require_relative 'vominator/ec2'
require_relative 'vominator/instances'
require_relative 'vominator/route53'
options = {}

OptionParser.new do |opts|
  opts.banner = 'Usage: vominate instance [options]'.yellow

  opts.on('-pPRODUCT', '--product PRODUCT', 'REQUIRED: The product which you want to manage instances for') do |value|
    options[:product] = value
  end

  opts.on('-eENVIRONMENT', '--environment ENVIRONMENT', 'REQUIRED: The environment which you want to manage instances for') do |value|
    options[:environment] = value
  end

  opts.on('-sSERVERS', '--servers SERVERS', 'OPTIONAL: Comma Delimited list of servers that you want to manage instances for') do |value|
    options[:servers] = value.split(',')
  end

  opts.on('-t', '--test', 'OPTIONAL: Test run. Show what would be changed without making any actual changes') do
    options[:test] = true
  end

  opts.on('--fix-security-groups', 'OPTIONAL: Fix an instances security groups') do
    options[:fix_security_groups] = true
  end

  opts.on('--disable-term-protection', 'OPTIONAL: This will disable termination protection on the targeted instances') do
    options[:disable_termination_protection] = true
  end

  opts.on('--terminate', 'OPTIONAL: This will terminate the specified instances. Must be combined with -s') do
    options[:terminate] = true
  end

  opts.on('--rebuild', 'OPTIONAL: This will terminate and relaunch the specified instances. Must be combined with -s') do
    options[:rebuild] = true
  end
  
  opts.on('-l', '--list', 'OPTIONAL: List out products and environments') do
    options[:list] = true
  end

  opts.on('-d', '--debug', 'OPTIONAL: debug output') do
    options[:debug] = true
  end

  opts.on_tail(:NONE, '-h', '--help', 'OPTIONAL: Display this screen') do
    puts opts
    exit
  end

  begin
    opts.parse!
    throw Exception unless ((options.include? :environment) && (options.include? :product)) || options[:list]
  rescue
    puts opts
    exit
  end
end

if options[:list]
  data = {}
  PUKE_CONFIG.keys.each do |environment|
    LOGGER.info "--#{environment}"
    products = PUKE_CONFIG[environment]['products'] || Array.new
    products.each do |product|
      LOGGER.info "  --#{product}"
    end
  end
  exit(1)
end

puke_config = Vominator.get_puke_variables(options[:environment])

#TODO: Validate Environment and Product
LOGGER.info("Working on #{options[:product]} in #{options[:environment]}.")

if options[:test]
  LOGGER.info('Vominator is running in test mode. It will NOT make any changes.')
else
  LOGGER.warning('WARNING: Vominator will make changes to your environment. Please run test mode first if you are unsure.')
  unless Vominator.yesno?(prompt: 'Do you wish to proceed?', default: false)
    exit(1)
  end
end

if options[:servers]
  instances = Vominator::Instances.get_instances(options[:environment], options[:product], options[:servers])
else
  instances = Vominator::Instances.get_instances(options[:environment], options[:product], false)
end

unless instances
  LOGGER.fatal('Unable to load instances. Make sure the product is correctly defined for the environment you have selected.')
end

#Get ec2 connection, which is then passed to specific functions. Maybe a better way to do this?
ec2 = Aws::EC2::Resource.new(region: puke_config['region_name'])
ec2_client = Aws::EC2::Client.new(region: puke_config['region_name'])

#Get some basic metadata about our existing instances in the account. Maybe look for ways to filter this for faster API response.
existing_instances = Hash.new
Vominator::EC2.get_instances(ec2).each do |instance|
  existing_instances[instance.private_ip_address] = [instance.id,instance.security_groups]
end

#Get route53 connection which is then passed to specific functions. Maybe a better way to do this?
r53 = Aws::Route53::Client.new(region: puke_config['region_name'])

#Get existing DNS entries for the zone.
route53_records = Vominator::Route53.get_records(r53, puke_config['zone'])


#Get existing Subnets for the VPC
existing_subnets = Vominator::EC2.get_subnets(ec2, puke_config['vpc_id'])

#Get existing Security Groups for the VPC
existing_security_groups = Vominator::EC2.get_security_groups(ec2, puke_config['vpc_id'])

instances.each do |instance|
  hostname = instance.keys[0]
  fqdn = "#{hostname}.#{options[:environment]}.#{puke_config['domain']}"
  instance_type = instance['type'][options[:environment]]
  instance_ip = instance['ip'].sub('OCTET',puke_config['octet'])
  instance_security_groups = instance['security_groups'].map { |sg| "#{options[:environment]}-#{sg}"}

  #TODO: IAM instance Profile

  if instance['environment'] && !instance['environment'].include?(options[:environment])
    LOGGER.info("#{fqdn} is not marked for deployment in #{options[:environment]}")
    next
  end

  if instance_type.nil?
    LOGGER.error("No instance size definition for #{fqdn}")
    next
  end

  if instance['ami']
    ami = instance['ami']
  else
    ami = Vominator::EC2.get_ami(puke_config,instance_type,instance['os'])
  end

  #Check to see if the subnet exists for the instance. If not we should create it.
  subnet = "#{instance_ip.rpartition('.')[0]}.0/24"
  unless existing_subnets[subnet]
    if options[:test]
      LOGGER.test("Would create a subnet for #{subnet} in #{instance['az']}")
    else
      existing_subnets[subnet] = Vominator::EC2.create_subnet(ec2, subnet, instance['az'], puke_config['vpc_id'])
      LOGGER.success("Created #{subnet} in #{instance['az']} for #{fqdn}")
    end
  end

  #If the instance exists, perform verification and other tasks on that instance
  if existing_instances[instance_ip]

    ec2_instance = Vominator::EC2.get_instance(ec2, existing_instances[instance_ip][0])

    if options[:terminate]
      #TODO: This would terminate an instance
      next
    end

    if options[:rebuild]
      #TODO: This would rebuild an instance
      next
    end

    if options[:disable_termination_protection]
      if options[:test]
        LOGGER.test("Would disable instance termination protection for #{fqdn}")
      else
        Vominator::EC2.set_termination_protection(ec2_client, ec2_instance.id, false)
        LOGGER.success("Disabled instance termination protection for #{fqdn}")
      end
    else
      unless Vominator::EC2.get_termination_protection(ec2_client, ec2_instance.id)
        if options[:test]
          LOGGER.test("Would enable instance termination protection for #{fqdn}")
        else
          Vominator::EC2.set_termination_protection(ec2_client, ec2_instance.id, true)
          LOGGER.success("Enabled instance termination protection for #{fqdn}")
        end
      end
    end

    if ec2_instance.instance_type != instance_type
      if options[:test]
        LOGGER.test("Would resize #{fqdn} from an #{ec2_instance.instance_type} to an #{instance_type}")
      else
        LOGGER.info("Resizing #{fqdn} from an #{ec2_instance.instance_type} to an #{instance_type}")
        if Vominator::EC2.set_instance_type(ec2, ec2_instance.id, instance_type, fqdn) == instance_type
          LOGGER.success("Succesfully resized #{fqdn} to #{instance_type}")
        else
          LOGGER.fatal("Failed to resize #{fqdn} to #{instance_type}")
        end
      end
    end

    #TODO: Manage EIP
    #require 'pry'
    #binding.pry
    if instance['eip'] && ec2_instance.public_ip_address.nil?
      if options[:test]
        LOGGER.test("Would create and associate a public IP for #{fqdn}")
      else
        LOGGER.info("Associating a public IP for #{fqdn}")
        eip = Vominator::EC2.assign_public_ip(ec2_client, ec2_instance.id)
        if eip
          LOGGER.success("Successfully associated #{eip} to #{fqdn}")
        else
          LOGGER.fatal("An error occured associating a public IP for #{fqdn}")
        end
      end
    elsif !instance['eip'] && ec2_instance.public_ip_address
      if options[:test]
        LOGGER.test("Would remove the elastic IP for #{fqdn}")
      else
        LOGGER.info("Removing public IP from #{fqdn}")
        if Vominator::EC2.remove_public_ip(ec2_client, ec2_instance.id)
          LOGGER.success("Successfully removed the public IP for #{fqdn}")
        else
          LOGGER.fatal("Failed to remove the public IP for #{fqdn}")
        end
      end
    end
    #TODO: Manage Source Dest Check

    #TODO: Manage EBS Optimization Flag

    #TODO: Manage Security Groups

  else #The instance does not exist, in which case we want to create it.
    #TODO: Instance Creation Logic

    #TODO: Post Instance Creation Tasks (DNS, EIP, EBS Volumes)

  end
end
