#!/usr/bin/env ruby
require 'rubygems'
require 'optparse'
require 'logger'
require 'colored'

options = {}

OptionParser.new do |opts|
  opts.banner = "Usage: vominate instance [options]".yellow

  opts.on("-d", "--debug", "debug output") do
    options[:debug] = true
  end

  opts.on_tail(:NONE, "-h", "--help", 'Display this screen') do
    puts opts
    exit
  end
end.parse!
