#!/usr/bin/env ruby
require 'rubygems'
require 'optparse'
require 'colored'
require './constants.rb'
require './aws.rb'
require './vominator/ec2.rb'
require './vominator/instances.rb'
require './vominator/route53.rb'

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
    LOGGER.INFO(opts)
    exit
  end

  begin
    opts.parse!
    throw Exception unless ((options.include? :environment) && (options.include? :product)) || options[:list]
  rescue
    LOGGER.error(opts)
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

#TODO: Validate Environment and Product
LOGGER.info("Working on #{options[:product]} in #{options[:environment]}.")

puke_config = Vominator.get_puke_variables(options[:environment])

if options[:test]
  LOGGER.info('Vominator is running in test mode. It will NOT make any changes.')
else
  LOGGER.warning('WARNING: Vominator will make changes to your environment. Please run test mode first if you are unsure.')
  unless Vominator.yesno('Do you wish to proceed?', false)
    exit(1)
  end
end
instances = Vominator::Instances.get_instances(options[:environment], options[:product])

unless instances
  LOGGER.error('Unable to load instances. Make sure the product is correctly defined for the environment you have selected.')
end

#Get ec2 connection, which is then passed to specific functions. Maybe a better way to do this?
ec2 = Aws::EC2::Resource.new(region: puke_config['region_name'])

#Get some basic metadata about our existing instances in the account. Maybe look for ways to filter this?
existing_instances = Hash.new
Vominator::EC2.get_instances(ec2).each do |instance|
  existing_instances[instance.private_ip_address] = [instance.id,instance.security_groups]
end

#Get route53 connection which is then passed to specific functions. Maybe a better way to do this?
r53 = Aws::Route53::Client.new(region: puke_config['region_name'])

#Get existing DNS entries for the zone.
route53_records = Vominator::Route53.get_records(r53, puke_config['zone'])

instances.each do |instance|

end
