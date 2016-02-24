#!/usr/bin/env ruby
require 'optparse'
require 'colored'
require_relative '../vominator/constants'
require_relative '../vominator/aws'
require_relative '../vominator/vpc'
require_relative '../vominator/ec2'
require_relative '../vominator/route53'

options = {}

OptionParser.new do |opts|
  opts.banner = 'Usage: vominate vpc create [options]'.yellow

  opts.on('-eENVIRONMENT', '--environment ENVIRONMENT', 'REQUIRED: The environment which you want to create a VPC for. IE foo') do |value|
    options[:environment] = value
  end

  opts.on('--region Region', 'REQUIRED: The AWS Region that you want to create the VPC in. IE us-east-1') do |value|
    options[:region] = value
  end

  opts.on('--availability-zones AVAILABILITY ZONES', 'OPTIONAL: A comma delimited list of specific availability zones that you want to prepare. If you don\'t specify then we will use all that are available. IE us-east-1c,us-east-1d,us-east-1e') do |value|
    options[:availability_zones] = value
  end

  opts.on('--parent-domain PARENT DOMAIN', 'REQUIRED: The parent domain name that will be used to create a seperate subdomain zone file for the new environment. IE, if you provide foo.org and your environment as bar, this will yield a new Route 53 zone file called bar.foo.org') do |value|
    options[:parent_domain] = value
  end

  opts.on('--cidr-block CIDR Block', 'REQUIRED: The network block for the new environment. This must be a /16 and the second octet should be unique for this environment. IE. 10.123.0.0/16') do |value|
    options[:cidr_block] = value
  end
  
  #opts.on('-t', '--test', 'OPTIONAL: Test run. Show what would be changed without making any actual changes') do
  #  options[:test] = true
  #end

  #opts.on('-l', '--list', 'OPTIONAL: List out Vominator aware VPCs') do
  #  options[:list] = true
  #end

  opts.on('-d', '--debug', 'OPTIONAL: debug output') do
    options[:debug] = true
  end

  opts.on_tail(:NONE, '-h', '--help', 'OPTIONAL: Display this screen') do
    puts opts
    exit
  end

  begin
    opts.parse!
    ## Validate Data Inputs
    throw Exception unless ((options.include? :environment) && (options.include? :region) && (options.include? :parent_domain) && (options.include? :cidr_block)) || options[:list]
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

unless test?('Vominator is running in test mode. It will NOT make any changes.')
  LOGGER.warning('WARNING: Vominator will make changes to your environment. Please run test mode first if you are unsure.')
  unless Vominator.yesno?(prompt: 'Do you wish to proceed?', default: false)
    exit(1)
  end
end

puke_config = Vominator.get_puke_variables(options[:environment])

if puke_config
  LOGGER.fatal("An environment with the name of #{options[:environment]} is already defined. Please choose a different name")
else  
  puke_config = Hash.new
  puke_config['region_name'] = options[:region]
end

ec2_client = Aws::EC2::Client.new(region: puke_config['region_name'])
r53_client = Aws::Route53::Client.new(region: puke_config['region_name'])


fqdn = "#{options[:environment]}.#{options[:parent_domain]}"

# Couple of sanity checks before we get started....
if Vominator::VPC.get_vpc_by_cidr(ec2_client, options[:cidr_block])
  LOGGER.warning("A VPC already exists with a netblock of #{options[:cidr_block]}. Generally you want these to be unique")
  unless Vominator.yesno?(prompt: 'Do you wish to proceed?', default: false)
    exit(1)
  end
end  

if Vominator::Route53.get_zone_by_domain(r53_client, fqdn)
  LOGGER.fatal("A Zonefile already exists for #{fqdn}. Please choose a different environment name")
end

if options[:availability_zones]
  availability_zones = options[:availability_zones].split(',')
else
  availability_zones = Vominator::AWS.get_availability_zones(ec2_client)
end

parent_zone = Vominator::Route53.get_zone_by_domain(r53_client, options[:parent_domain])

unless parent_zone
  LOGGER.warning("We could not find the parent zone of #{options[:parent_domain]}. You can proceed and we will provide the settings so you can manually create the entry.")
  unless Vominator.yesno?(prompt: 'Do you wish to proceed?', default: false)
    exit(1)
  end
end


LOGGER.info("Starting the creation process. This may take a couple of minutes")

environment_zone = Vominator::Route53.create_zone(r53_client, fqdn)

if parent_zone
  Vominator::Route53.create_nameserver_records(r53_client,parent_zone.id, fqdn, environment_zone.delegation_set.name_servers)
end

vpc = Vominator::VPC.create_vpc(ec2_client,options[:cidr_block])

gateway = Vominator::VPC.create_internet_gateway(ec2_client)

Vominator::VPC.attach_internet_gateway(ec2_client, gateway.internet_gateway_id, vpc.vpc_id)

public_route_table = Vominator::VPC.get_route_tables(ec2_client, vpc.vpc_id).first
Vominator::EC2.tag_resource(ec2_client, public_route_table.route_table_id,[{key: 'Name', value: "dmz-#{options[:environment]}-#{options[:region]}"}])
  
Vominator::VPC.create_internet_gateway_route(ec2_client, public_route_table.route_table_id, '0.0.0.0/0', gateway.internet_gateway_id)

third_octet = 1

route_tables = Hash.new
route_tables['public'] = public_route_table.route_table_id

availability_zones.each do |zone|

  private_route_table = Vominator::VPC.create_route_table(ec2_client, vpc.vpc_id)
  route_tables[zone] = private_route_table.route_table_id

  Vominator::EC2.tag_resource(ec2_client, private_route_table.route_table_id,[{key: 'Name', value: "nat-#{options[:environment]}-#{zone}"}])

  public_subnet_cidr_block = "#{options[:cidr_block].split('.')[0]}.#{options[:cidr_block].split('.')[1]}.#{third_octet}.0/24"
  public_subnet = Vominator::VPC.create_subnet(ec2_client, vpc.vpc_id, public_subnet_cidr_block, zone)

  Vominator::VPC.associate_route_table(ec2_client, public_subnet.subnet_id, public_route_table.route_table_id)

  public_ip = Vominator::EC2.allocate_public_ip(ec2_client)
  nat_gateway = Vominator::VPC.create_nat_gateway(ec2_client, public_subnet.subnet_id, public_ip.allocation_id)

  Vominator::VPC.create_nat_gateway_route(ec2_client, private_route_table.route_table_id, '0.0.0.0/0', nat_gateway.nat_gateway_id)

  third_octet += 1
end

unless parent_zone
  LOGGER.warning("Parent zone not was not found in Route53. Use the below information to create the proper entries in your parent zone.")
  LOGGER.warning("FQDN: #{fqdn}")
  LOGGER.warning("Record Type: NS")
  LOGGER.warning("Nameservers: #{environment_zone.delegation_set.name_servers}")
end

config = {
    options[:environment] => {
        'vpc_id' => vpc.vpc_id,
        'route_tables' => route_tables,
        'region_name' => options[:region],
        'zone' => environment_zone.hosted_zone.id.split('/')[2],
        'octet' => options[:cidr_block].split('.')[1],
        'domain' => fqdn,
        'linux_cloud_config_template' => 'EDIT_ME',
        'linux_paravirtual_base_image' => 'EDIT_ME',
        'linux_hvm_base_image' => 'EDIT_ME',
        'windows_cloud_config_template' => 'EDIT_ME',
        'windows_paravirtual_base_image' => 'EDIT_ME',
        'windows_hvm_base_image' => 'EDIT_ME',
        'chef_host' => 'EDIT_ME',
        'products' => []
    }}

LOGGER.success("Append the below to your config.yaml file in your puke directory")
LOGGER.info(config.to_yaml)
