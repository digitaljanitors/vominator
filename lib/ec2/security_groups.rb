#!/usr/bin/env ruby
require 'optparse'
require 'colored'
require_relative '../vominator/constants'
require_relative '../vominator/aws'
require_relative '../vominator/security_groups'

options = {}

OptionParser.new do |opts|
  opts.banner = 'Usage: vominate ec2 security_groups [options]'.yellow

  opts.on('-p PRODUCT', '--product PRODUCT', String, 'REQUIRED: The product which you want to manage security groups for') do |value|
    options[:product] = value
  end

  opts.on('-e ENVIRONMENT', '--environment ENVIRONMENT', String, 'REQUIRED: The environment which you want to manage security groups for') do |value|
    options[:environment] = value
  end

  opts.on('--security-groups GROUPS', Array, 'OPTIONAL: Comma Delimited list of security groups') do |value|
    options[:groups] = value
  end

  opts.on('-t', '--test', 'OPTIONAL: Test run. Show what would be changed without making any actual changes') do
    options[:test] = true
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

if options[:groups]
  security_groups = Vominator::SecurityGroups.get_security_groups(options[:environment], options[:product], options[:groups])
  # TODO: Report back if provided security groups dont exist
else
  security_groups = Vominator::SecurityGroups.get_security_groups(options[:environment], options[:product])
end

unless security_groups 
  LOGGER.fatal('Unable to load security groups . Make sure the product is correctly defined for the environment you have selected.')
end

#TODO: Get security groups for environment from amazon and create if not test
#TODO: Report what groups we would create
#TODO: Report what groups exist on amazon, but that we dont have defined

#TODO: Now that we know all groups exist, loop over each group
  #TODO: Get existing ingress/egress rules
  #TODO: Capture rules which exist but arent defined in our puke
  #TODO: Setup new Ingress/Egress rules
  #TODO: Delete undefined rules if not defined
