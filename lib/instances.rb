#!/usr/bin/env ruby
require 'rubygems'
require 'optparse'
require 'colored'
require './constants.rb'
require './aws.rb'
require './vominator/ec2.rb'
require './vominator/instances.rb'

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
    LOGGER.ERROR(opts)
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

instances = Vominator::Instances.get_instances(options[:environment], options[:product])

unless instances
  LOGGER.error('Unable to load instances. Make sure the product is correctly defined for the environment you have selected.')
end

instances.each do |instance|
  LOGGER.info(instance)
end