#!/usr/bin/env ruby
require 'optparse'
require 'colored'
require_relative '../vominator/constants'
require_relative '../vominator/aws'
require_relative '../vominator/ssm'

options = {}

OptionParser.new do |opts|
  opts.banner = 'Usage: vominate ssm [options]'.yellow

  opts.on('-eENVIRONMENT', '--environment ENVIRONMENT', 'REQUIRED: The environment which you want to manage ssm for') do |value|
    options[:environment] = value
  end

  opts.on('-t', '--test', 'OPTIONAL: Test run. Show what would be changed without making any actual changes') do
    options[:test] = true
  end

  opts.on('-l', '--list', 'OPTIONAL: List out documents for a specific environment') do
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
    throw Exception unless (options.include? :environment) || options[:list]
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

puke_config = Vominator.get_puke_variables(options[:environment])

#TODO: Validate Environment
LOGGER.info("Working on #{options[:environment]}.")

unless test?('Vominator is running in test mode. It will NOT make any changes.')
  LOGGER.warning('WARNING: Vominator will make changes to your environment. Please run test mode first if you are unsure.')
  unless Vominator.yesno?(prompt: 'Do you wish to proceed?', default: false)
    exit(1)
  end
end

Aws.config[:credentials] = Aws::SharedCredentials.new(:profile_name => puke_config['account'])
ssm = Aws::SSM::Client.new(region: puke_config['region_name'])

aws_documents = Vominator::SSM.get_documents(ssm)

puke_config['ssm_documents'].each do |document_name|
  document_data = File.read("#{VOMINATOR_CONFIG['configuration_path']}/ssm-documents/#{document_name}")

  if aws_documents.include? document_name
    #should we delete it?

    #should we update it?
  else
    unless test?("Would create SSM document for #{document_name}")
      if Vominator::SSM.put_document(ssm,document_name,document_data)
        LOGGER.success("Succesfully created SSM document #{document_name}")
      else
        LOGGER.fatal("Failed to create SSM document #{document_name}")
      end
    end
  end
end
