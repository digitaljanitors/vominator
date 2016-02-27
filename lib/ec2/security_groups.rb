#!/usr/bin/env ruby
require 'optparse'
require 'colored'
require 'terminal-table'
require_relative '../vominator/constants'
require_relative '../vominator/aws'
require_relative '../vominator/security_groups'
require_relative '../vominator/ec2'

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

  opts.on('--delete', 'Enable Deletions. This should be used with care') do |value|
    options[:delete] = value
  end
  opts.on('-t', '--test', 'OPTIONAL: Test run. Show what would be changed without making any actual changes') do
    options[:test] = true
  end

  opts.on('-l', '--list', 'OPTIONAL: List out products and environments') do
    options[:list] = true
  end

  opts.on('--verbose', 'OPTIONAL: Show all security group rules in tables') do
    options[:verbose] = true
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
  puke_security_groups = Vominator::SecurityGroups.get_security_groups(options[:environment], options[:product], options[:groups])
  # If the user specified a filter, barf in the event a specified security group doesnt exist in puke
  invalid_security_groups = options[:groups].reject{|g| puke_security_group_names.include? g}
  if invalid_security_groups.count > 0
    LOGGER.fatal("Unable to find the following security groups in your puke: #{invalid_security_groups.join(',')}")
  end  
else
  puke_security_groups = Vominator::SecurityGroups.get_security_groups(options[:environment], options[:product])
end

unless puke_security_groups
  LOGGER.fatal('Unable to load security groups . Make sure the product is correctly defined for the environment you have selected and that a security_groups.yaml file exists with at least one group defined.')
end

ec2_client = Aws::EC2::Client.new(region: puke_config['region_name'])


puke_security_group_names = puke_security_groups.map{|g| g.keys[0]}
vpc_security_groups = Vominator::EC2.get_security_groups(ec2_client, puke_config['vpc_id'])
vpc_security_group_names = vpc_security_groups.map{|g| g.group_name }

new_security_group_names = puke_security_group_names.reject{|g| vpc_security_group_names.include? g}
if new_security_group_names.count > 0
  unless test?("Would create the following new security groups: #{new_security_group_names.join(',')}")
    new_security_group_names.each do |security_group_name|
	    #TODO: Automagically nuke the default outbound ACL for each security group
      description = puke_security_groups.select{ |g| g.keys[0] == security_group_name}.first['description']
      LOGGER.success("Successfully created #{security_group_name}") if Vominator::EC2.create_security_group(ec2_client, security_group_name, puke_config['vpc_id'], description)
    end
    # Sleep for just a second to allow amazon to converge
    sleep(1)
  end
end

untracked_security_group_names = vpc_security_group_names.reject{|g| puke_security_group_names.include? g}
if untracked_security_group_names.count > 0
	LOGGER.warning("The following security groups exist in the AWS account but are not defined in your puke: #{untracked_security_group_names.join(',')}")
end

# Refresh our list of existing security groups now that we have created ones we need.
vpc_security_groups = Vominator::EC2.get_security_groups(ec2_client, puke_config['vpc_id'])
vpc_security_groups_id_lookup = Hash[vpc_security_groups.map{|g| [g.group_name, g.group_id]}]
vpc_security_groups_name_lookup = Hash[vpc_security_groups.map{|g| [g.group_id, g.group_name]}]

puke_security_groups.each do |puke_security_group|
	puke_security_group_name = puke_security_group.keys[0]
  vpc_security_group = vpc_security_groups.select{|g| g.group_name == puke_security_group_name}.first

	# Create empty arrays if we havent specified either ingress or egress rules.
	puke_security_group['ingress'] = [] unless puke_security_group['ingress'] && puke_security_group['ingress'].count > 0
  puke_security_group['egress'] = [] unless puke_security_group['egress'] && puke_security_group['egress'].count > 0

  if vpc_security_group
		# Update environment tag if needed
		environment_tag = vpc_security_group.tags.select{|t| t.key == 'Environment'}.first

    environment_tag = nil if environment_tag.value != options[:environment] if environment_tag

    unless environment_tag
      unless test?("Would set environment tag to #{options[:environment]} for #{puke_security_group_name}")
        Vominator::EC2.tag_resource(ec2_client, vpc_security_group.group_id, [{key: 'Environment', value: options[:environment]}])
        LOGGER.info("Updated tags for #{puke_security_group_name}")
      end
    end

		# Normalize the existing ingress rules for the security group.
    vpc_ingress_rules = Array.new
    vpc_security_group.ip_permissions.each do |rule|
      #TODO: Normalize -1 to all for ip_protocol
	    #TODO: if -1 for ip_protocol set :from_port and to_ports

	    rule.ip_ranges.each do |ip_range|
        vpc_ingress_rules.push({ :ip_protocol => rule.ip_protocol, :from_port => rule.from_port, :to_port => rule.to_port, :cidr_ip => ip_range.cidr_ip, :source_security_group_id => nil })
	    end

			rule.user_id_group_pairs.each do |group|
        vpc_ingress_rules.push({ :ip_protocol => rule.ip_protocol, :from_port => rule.from_port, :to_port => rule.to_port, :cidr_ip => nil, :source_security_group_id => group.group_id, :source_security_group_name => vpc_security_groups_name_lookup[group.group_id] })
      end
    end

		# Normalize the rules that we defined in puke for the security group.
		puke_ingress_rules = Array.new
		cidr_block_regex = /^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\/([0-9]|[0-2][0-9]|3[0-2]))$/

		puke_security_group['ingress'].each do |rule|

			# If this specific rule is marked for specific environments and this one isnt it then skip over it.
			if rule['environments'] && !rule['environments'].include?(options[:environment])
				LOGGER.info("Skipping over #{rule} as its not marked for creation in #{options[:environment]}")
				next
			end

      #TODO: Normalize all to -1 for ip_protocol
			if rule['ports'].to_s.include?('..')
        from_port = rule['ports'].split('..')[0]
				to_port = rule['ports'].split('..')[1]
			else
				from_port = rule['ports']
				to_port = rule['ports']
			end

			if rule['source'] =~ cidr_block_regex
        puke_ingress_rules.push({ :ip_protocol => rule['protocol'], :from_port => from_port.to_i, :to_port => to_port.to_i, :cidr_ip => rule['source'], :source_security_group_id => nil})
			else rule['source']
			  if vpc_security_groups_id_lookup[rule['source']]
          group_id = vpc_security_groups_id_lookup[rule['source']]
          puke_ingress_rules.push({ :ip_protocol => rule['protocol'], :from_port => from_port.to_i, :to_port => to_port.to_i, :cidr_ip => nil, :source_security_group_id => group_id, :source_security_group_name => vpc_security_groups_name_lookup[group_id] })
			  else
				  LOGGER.fatal("Do not recognize #{rule['source']} as a valid cidr block and was unable to resolve this to a valid security group for #{rule} in #{puke_security_group_name}")
				end
			end
		end

		# Determie what new rules we need to add
    ingress_to_create = puke_ingress_rules - vpc_ingress_rules
		# Determine what rules we should delete
		ingress_to_delete = vpc_ingress_rules - puke_ingress_rules

		# Normalize the existing egress rules for the security group
    vpc_egress_rules = Array.new
		vpc_security_group.ip_permissions_egress.each do |rule|
			#TODO: Normalize -1 to all for ip_protocol
      #TODO: if -1 for ip_protocol set :from_port and to_ports
      rule.ip_ranges.each do |ip_range|
        vpc_egress_rules.push({ :ip_protocol => rule.ip_protocol, :from_port => rule.from_port, :to_port => rule.to_port, :cidr_ip => ip_range.cidr_ip, :destination_security_group_id => nil })
      end
      
      rule.user_id_group_pairs.each do |group|
        vpc_egress_rules.push({ :ip_protocol => rule.ip_protocol, :from_port => rule.from_port, :to_port => rule.to_port, :cidr_ip => nil, :destination_security_group_id => group.group_id, :destination_security_group_name => vpc_security_groups_name_lookup[group.group_id] })
      end
		end
    
    # Normalize the rules that we defined in puke for the security group.
    puke_egress_rules = Array.new
    cidr_block_regex = /^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\/([0-9]|[0-2][0-9]|3[0-2]))$/
    
    puke_security_group['egress'].each do |rule|

	    # If this specific rule is marked for specific environments and this one isnt it then skip over it.
	    if rule['environments'] && !rule['environments'].include?(options[:environment])
		    LOGGER.info("Skipping over #{rule} as its not marked for creation in #{options[:environment]}")
		    next
	    end

      #TODO: Normalize all to -1 for ip_protocol
      if rule['ports'].to_s.include?('..')
        from_port = rule['ports'].split('..')[0]
        to_port = rule['ports'].split('..')[1]
      else
        from_port = rule['ports']
        to_port = rule['ports']
      end

      if rule['destination'] =~ cidr_block_regex
        puke_egress_rules.push({ :ip_protocol => rule['protocol'], :from_port => from_port.to_i, :to_port => to_port.to_i, :cidr_ip => rule['destination'], :destination_security_group_id => nil})
      else rule['destination']
      if vpc_security_groups_id_lookup[rule['destination']]
        group_id = vpc_security_groups_id_lookup[rule['destination']]
        puke_egress_rules.push({ :ip_protocol => rule['protocol'], :from_port => from_port.to_i, :to_port => to_port.to_i, :cidr_ip => nil, :destination_security_group_id => group_id, :destination_security_group_name => vpc_security_groups_name_lookup[group_id] })
      else
        LOGGER.fatal("Do not recognize #{rule['destination']} as a valid cidr block and was unable to resolve this to a valid security group for #{rule} in #{puke_security_group_name}")
      end
      end
    end
    
    # Determine what new rules we need to add
    egress_to_create = puke_egress_rules - vpc_egress_rules
    # Determine what rules we should delete
    egress_to_delete = vpc_egress_rules - puke_egress_rules
		
    table = Terminal::Table.new :title => puke_security_group_name.cyan, :headings => ['Type', 'Source', 'from port', 'to_port', 'Protocol', 'Action'], :style => {:width => 125} do |t|
      ingress_to_create.each do |rule|
	      source = rule[:cidr_ip] || rule[:source_security_group_name]
	      t.add_row ['Inbound'.green, source.green, rule[:from_port].to_s.green, rule[:to_port].to_s.green, rule[:ip_protocol].green, 'Create'.green]
      end

      ingress_to_delete.each do |rule|
        source = rule[:cidr_ip] || rule[:source_security_group_name]
        t.add_row ['Inbound'.red, source.red, rule[:from_port].to_s.red, rule[:to_port].to_s.red, rule[:ip_protocol].red, 'Delete'.red]
      end

      if options[:verbose]
        ((vpc_ingress_rules - ingress_to_create) - ingress_to_delete).each do |rule|
	        source = rule[:cidr_ip] || rule[:source_security_group_name]
          t.add_row ['Inbound', source, rule[:from_port].to_s, rule[:to_port].to_s, rule[:ip_protocol], nil]
        end
      end

      egress_to_create.each do |rule|
        destination = rule[:cidr_ip] || rule[:destination_security_group_name]
        t.add_row ['Outbound'.green, destination.green, rule[:from_port].to_s.green, rule[:to_port].to_s.green, rule[:ip_protocol].green, 'Create'.green]
      end

      egress_to_delete.each do |rule|
        destination = rule[:cidr_ip] || rule[:destination_security_group_name]
        t.add_row ['Outbound'.red, destination.red, rule[:from_port].to_s.red, rule[:to_port].to_s.red, rule[:ip_protocol].red, 'Delete'.red]
      end

      if options[:verbose]
        ((vpc_egress_rules - egress_to_create) - egress_to_delete).each do |rule|
          destination = rule[:cidr_ip] || rule[:destination_security_group_name]
          t.add_row ['Outbound', destination, rule[:from_port].to_s, rule[:to_port].to_s, rule[:ip_protocol], nil]
        end
      end
    end


		LOGGER.info(table)

    #TODO: Maybe find a way to cleanup the display output better on success
		unless options[:test]
			ingress_to_create.each do |rule|
				Vominator::EC2.create_security_group_rule(ec2_client,'ingress',vpc_security_group.group_id,rule)
				LOGGER.success("Added inbound rule to #{vpc_security_group.group_name}: #{rule}")
			end


			egress_to_create.each do |rule|
        Vominator::EC2.create_security_group_rule(ec2_client,'egress',vpc_security_group.group_id,rule)
        LOGGER.success("Added outbound rule to #{vpc_security_group.group_name}: #{rule}")
			end

			if options[:delete]
        ingress_to_delete.each do |rule|
          Vominator::EC2.delete_security_group_rule(ec2_client,'ingress',vpc_security_group.group_id,rule)
          LOGGER.success("Removed inbound rule to #{vpc_security_group.group_name}: #{rule}")
        end

        egress_to_delete.each do |rule|
          Vominator::EC2.delete_security_group_rule(ec2_client,'egress',vpc_security_group.group_id,rule)
          LOGGER.success("Removed outbound rule to #{vpc_security_group.group_name}: #{rule}")
        end
			end
		end
  end
end
