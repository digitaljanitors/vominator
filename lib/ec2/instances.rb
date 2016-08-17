#!/usr/bin/env ruby
require 'optparse'
require 'colored'
require_relative '../vominator/constants'
require_relative '../vominator/aws'
require_relative '../vominator/ec2'
require_relative '../vominator/instances'
require_relative '../vominator/route53'
require_relative '../vominator/ssm'

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

  opts.on('--disable-term-protection', 'OPTIONAL: This will disable termination protection on the targeted instances') do
    options[:disable_term_protection] = true
  end

  opts.on('--terminate', 'OPTIONAL: This will terminate the specified instances.') do
    options[:terminate] = true
  end

  opts.on('--rebuild', 'OPTIONAL: This will terminate and relaunch the specified instances.') do
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
    if options[:terminate] || options[:rebuild]
      throw Exception unless (options[:disable_term_protection])
    end

  rescue
    puts opts
    exit
  end
end

TEST = options[:test]
def test?(message)
  LOGGER.test(message) if TEST
  TEST
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


unless test?('Vominator is running in test mode. It will NOT make any changes.')
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
Aws.config[:credentials] = Aws::SharedCredentials.new(:profile_name => puke_config['account'])
ec2 = Aws::EC2::Resource.new(region: puke_config['region_name'])
ec2_client = Aws::EC2::Client.new(region: puke_config['region_name'])

#Get some basic metadata about our existing instances in the account. Maybe look for ways to filter this for faster API response.
ec2_instances = Vominator::EC2.get_instances(ec2)

#Get route53 connection which is then passed to specific functions. Maybe a better way to do this?
r53 = Aws::Route53::Client.new(region: puke_config['region_name'])

#Get existing DNS entries for the zone.
route53_records = Vominator::Route53.get_records(r53, puke_config['zone'])

#Get SSM connection
ssm = Aws::SSM::Client.new(region: puke_config['region_name'])

#Get existing Subnets for the VPC
existing_subnets = Vominator::EC2.get_subnets(ec2, puke_config['vpc_id'])

#Get existing Security Groups for the VPC
vpc_security_groups = Vominator::EC2.get_security_group_name_ids_hash(ec2, puke_config['vpc_id'])

instances.each do |instance|
  hostname = instance.keys[0]
  fqdn = "#{hostname}.#{puke_config['domain']}"
  instance_type = instance['type'][options[:environment]] || instance['type']
  instance_ip = instance['ip'].sub('OCTET',puke_config['octet'])
  instance_security_groups = instance['security_groups'].map { |sg| sg}.uniq.sort
  ebs_optimized = instance['ebs_optimized'].nil? ? false : instance['ebs_optimized']
  source_dest_check = instance['source_dest_check'].nil? ? true : instance['source_dest_check']
  instance_ebs_volumes = instance['ebs'].nil? ? [] : instance['ebs']
  key_name = Vominator.get_key_pair(VOMINATOR_CONFIG)
  ssm_documents = instance['ssm_documents'].nil? ? [] : instance['ssm_documents']
  instance_az = instance['az'][options[:environment]] || instance['az']
  instance_tags = instance['tags']

  LOGGER.info("Working on #{fqdn}")

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
    ami = Vominator::EC2.get_ami(puke_config,instance_type,instance['family'])
  end

  #Check to see if the subnet exists for the instance. If not we should create it.
  subnet = "#{instance_ip.rpartition('.')[0]}.0/24"
  unless existing_subnets[subnet]
    unless test?("Would create a subnet for #{subnet} in #{instance_az} and associate with the appropriate routing table")
      existing_subnets[subnet] = Vominator::EC2.create_subnet(ec2, subnet, instance_az, puke_config['vpc_id'], puke_config['route_tables'][instance_az])
      LOGGER.success("Created #{subnet} in #{instance_az} for #{fqdn}")
    end
  end

  #If the instance exists, perform verification and other tasks on that instance
  if ec2_instances[instance_ip]

    ec2_instance = Vominator::EC2.get_instance(ec2, ec2_instances[instance_ip][:instance_id])
    ec2_instance_security_groups = ec2_instances[instance_ip][:security_groups].uniq.sort
    ec2_instance_ebs_volumes = Vominator::EC2.get_instance_ebs_volumes(ec2, ec2_instances[instance_ip][:instance_id])
    ec2_instance_tags = Hash[ec2_instance.tags.map{ |x| [x.key, x.value]}]

    if options[:disable_term_protection]
      unless test?("Would disable instance termination protection for #{fqdn}")
        Vominator::EC2.set_termination_protection(ec2_client, ec2_instance.id, false)
        LOGGER.success("Disabled instance termination protection for #{fqdn}")
      end
    else
      unless Vominator::EC2.get_termination_protection(ec2_client, ec2_instance.id)
        unless test?("Would enable instance termination protection for #{fqdn}")
          Vominator::EC2.set_termination_protection(ec2_client, ec2_instance.id, true)
          LOGGER.success("Enabled instance termination protection for #{fqdn}")
        end
      end
    end

    if options[:terminate] #check if the instance even exists?
      unless test?("Would terminate #{fqdn}")
        if Vominator::EC2.terminate_instance(ec2,ec2_instances[instance_ip][:instance_id])
          LOGGER.success("Succesfully terminated #{fqdn}")
          LOGGER.info('Performing Cleanup Tasks...')
          if Vominator::Route53.delete_record(r53,puke_config['zone'],fqdn, instance_ip)
            LOGGER.success("Removed DNS entry for #{fqdn}")
          end
        else
          LOGGER.fatal("Failed to terminate #{fqdn}")
        end
        #TODO: Should include deleting chef client and node.
      end
      next
    end

    if options[:rebuild]
      unless test?("Would rebuild #{fqdn}")
        if Vominator::EC2.terminate_instance(ec2,ec2_instances[instance_ip][:instance_id])
          LOGGER.success("Succesfully terminated #{fqdn}")
          LOGGER.info("Triggering rebuild of #{fqdn}")
          ec2_instances.delete(instance_ip)
        else
          LOGGER.fatal("Failed to terminate #{fqdn}")
        end
        #TODO: Should include deleting chef client and node.
      end
      options[:rebuild] = false
      options[:disable_term_protection] = false
      redo
    end

    if ec2_instance.instance_type != instance_type
      unless test?("Would resize #{fqdn} from an #{ec2_instance.instance_type} to an #{instance_type}")
        LOGGER.info("Resizing #{fqdn} from an #{ec2_instance.instance_type} to an #{instance_type}")
        if Vominator::EC2.set_instance_type(ec2, ec2_instance.id, instance_type, fqdn) == instance_type
          LOGGER.success("Succesfully resized #{fqdn} to #{instance_type}")
        else
          LOGGER.fatal("Failed to resize #{fqdn} to #{instance_type}")
        end
      end
    end

    if instance['eip'] && ec2_instance.public_ip_address.nil?
      unless test?("Would create and associate a public IP for #{fqdn}")
        LOGGER.info("Associating a public IP for #{fqdn}")
        eip = Vominator::EC2.assign_public_ip(ec2_client, ec2_instance.id)
        if eip
          LOGGER.success("Successfully associated #{eip} to #{fqdn}")
        else
          LOGGER.fatal("An error occured associating a public IP for #{fqdn}")
        end
      end
    elsif !instance['eip'] && ec2_instance.public_ip_address
      unless test?("Would remove the elastic IP for #{fqdn}")
        LOGGER.info("Removing public IP from #{fqdn}")
        if Vominator::EC2.remove_public_ip(ec2_client, ec2_instance.id)
          LOGGER.success("Successfully removed the public IP for #{fqdn}")
        else
          LOGGER.fatal("Failed to remove the public IP for #{fqdn}")
        end
      end
    end

    unless ec2_instance.source_dest_check == source_dest_check
      unless test?("Would set the source_dest_check to #{source_dest_check}")
        if Vominator::EC2.set_source_dest_check(ec2, ec2_instance.id, source_dest_check) == source_dest_check
          LOGGER.success("Succesfully set source destination check to #{source_dest_check} for #{fqdn}")
        else
          LOGGER.fatal("Failed to set source destination check to #{source_dest_check} for #{fqdn}")
        end
      end
    end

    unless ec2_instance.ebs_optimized == ebs_optimized
      unless test?("Would set EBS optimization to #{ebs_optimized}")
        if Vominator::EC2.set_ebs_optimized(ec2, ec2_instance.id, ebs_optimized, fqdn) == ebs_optimized
          LOGGER.success("Succesfully set EBS optimization to #{ebs_optimized} for #{fqdn}")
        else
          LOGGER.fatal("Failed to set EBS optimization to #{ebs_optimized} for #{fqdn}")
        end
      end
    end

    unless ec2_instance_security_groups == instance_security_groups
      LOGGER.info("Security group mismatch detected for #{fqdn}")
      sg_missing = instance_security_groups - ec2_instance_security_groups
      sg_undefined = ec2_instance_security_groups - instance_security_groups

      if sg_missing.count > 0
        unless test?("Would add #{sg_missing.join(', ')} to #{fqdn}")
          LOGGER.info("#{fqdn} is missing the following security groups: #{sg_missing.join(', ')}")
          updated_groups = instance_security_groups - Vominator::EC2.set_security_groups(ec2, ec2_instance.id, instance_security_groups, vpc_security_groups)
          if updated_groups.count > 0
            LOGGER.warning "Failed to set #{updated_groups.join(', ')} for #{fqdn}"
          else
            LOGGER.success "Succesfully set security groups for #{fqdn}"
          end
        end
      end

      if sg_undefined.count > 0
        unless test?("Would remove #{sg_undefined.join(', ')} from #{fqdn}")
          LOGGER.warning("#{fqdn} has the following extra security groups: #{sg_undefined.join(', ')}. You will be prompted to remove these.")
          if Vominator.yesno?(prompt: 'Is it safe to remove these groups?', default: false)
            if Vominator::EC2.set_security_groups(ec2, ec2_instance.id, instance_security_groups, vpc_security_groups, false) == instance_security_groups
              LOGGER.success("Succesfully updated the security groups for #{fqdn}")
            else
              LOGGER.fatal("Failed to remove security groups from #{fqdn}")
            end
          end
        end
      end
    end

    instance_ebs_volumes.each do |device,options|
      unless ec2_instance_ebs_volumes.include? device
        unless test?("Would create and mount a #{options['type']} EBS volume on #{device} for #{fqdn}")
          if Vominator::EC2.add_ebs_volume(ec2, ec2_instance.id, options['type'], options['size'], device, options['iops'], options['encrypted'])
            LOGGER.success("Succesfully created and mounted #{device} to #{fqdn}")
          else
            LOGGER.fatal("Failed to create and mount #{device} to #{fqdn}")
          end
        end
      end
    end

    unless route53_records.include?("#{fqdn}.")
      unless test?("Would add a DNS record for #{fqdn}")
        if Vominator::Route53.create_record(r53,puke_config['zone'],fqdn,instance_ip)
          LOGGER.success("Succesfuly created a dns record for #{fqdn}")
        else
          LOGGER.fatal("Failed to create a DNS record for #{fqdn}")
        end
      end
    end

    ssm_documents.each do |doc_name|
      unless Vominator::SSM.associated?(ssm,doc_name,ec2_instance.id)
        unless test?("Would associate SSM Document #{doc_name} to #{fqdn}")
          if Vominator::SSM.create_association(ssm,doc_name,ec2_instance.id)
            LOGGER.success("Succesfully associated #{doc_name} to #{fqdn}")
          else
            LOGGER.fatal("Failed to associate #{doc_name} to #{fqdn}")
          end
        end
      end
    end
    
    instance_tags.each do |tag|
      key = tag.split('=')[0]
      value = tag.split('=')[1]
      unless ec2_instance_tags.key?(key) || (ec2_instance_tags.key?(key) && ec2_instance_tags[key] != value)
        unless test?("Would create or update tag #{key}:#{value} on #{fqdn}")
          Vominator::EC2.tag_resource(ec2_client, ec2_instance.id, [{key: key, value: value}])
          LOGGER.success("Created or Updated tag #{key}:#{value} on #{fqdn}")
        end 
      end
    end

  else #The instance does not exist, in which case we want to create it.
    user_data = Vominator::Instances.generate_cloud_config(hostname, options[:environment], options[:environment].gsub('.','-'), instance['family'], instance['chef_roles'], instance['chef_recipes'])
    security_group_ids = instance_security_groups.map {|sg| vpc_security_groups[sg] }.compact
    unless test?("Would create #{fqdn}")
      ec2_instance = Vominator::EC2.create_instance(ec2, hostname, options[:environment], ami, existing_subnets[subnet].id, instance_type, key_name, instance_ip, instance_az, security_group_ids, user_data, ebs_optimized, instance['iam_profile'])
      if ec2_instance
        LOGGER.success("Succesfully created #{fqdn}")
        ec2_instances[instance_ip] = {:instance_id => ec2_instance.id, :security_groups => ec2_instance.security_groups.map { |sg| sg.group_name}}
        redo
      else
        LOGGER.fatal("Failed to create #{fqdn}")
      end
    end
  end
end
