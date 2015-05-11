#!/usr/bin/env ruby
require 'rubygems'
require 'optparse'
require 'logger'
require 'colored'
require './constants.rb'
require './aws.rb'

options = {}

OptionParser.new do |opts|
  opts.banner = 'Usage: vominate instance [options]'.yellow

  opts.on('-p', '--product', 'REQUIRED: The product which you want to manage instances for') do |value|
    options[:product] = value
  end

  opts.on('-e', '--environment', 'REQUIRED: The environment which you want to manage instances for') do |value|
    options[:environment] = value
  end

  opts.on('-s', '--servers', 'OPTIONAL: Comma Delimited list of servers that you want to manage instances for') do |value|
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
    throw Exception unless (options.include? :environment) && (options.include? :product)
  rescue
    puts opts
    exit
  end
end
