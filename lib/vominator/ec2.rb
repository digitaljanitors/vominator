require 'aws-sdk'
require 'base64'
require_relative 'constants'
require_relative 'ec2info'

module Vominator
  class EC2
    def self.get_virt_type(instance_type)
      begin
        return Vominator::EC2Info.get(instance_type).virtualization_type
      rescue NoMethodError
        raise ArgumentError, 'You must specify a valid instance type'
      end
    end

    def self.get_ephemeral_dev_count(instance_type)
      Vominator::EC2Info.get(instance_type).ephemeral_devices
    end

    def self.get_instances(resource)
      instances = Hash.new
      resource.instances.each do |instance|
        instances[instance.private_ip_address] = {:instance_id => instance.id, :security_groups => instance.security_groups.map { |sg| sg.group_name}}
      end
      return instances
    end

    def self.get_instance(resource, instance_id)
      return resource.instances(filters: [{name: 'instance-id', values: [instance_id]}]).first
    end

    def self.get_security_group_name_ids_hash(resource, vpc_id)
      security_groups = Hash.new
      resource.vpcs(filters: [{name: 'vpc-id', values: [vpc_id]}]).first.security_groups.each do |security_group|
        security_groups[security_group.group_name] = security_group.id
      end
      return security_groups
    end

    def self.get_subnets(resource, vpc_id)
      subnets = Hash.new
      resource.vpcs(filters: [{name: 'vpc-id', values: [vpc_id]}]).first.subnets.each do |subnet|
        subnets[subnet.cidr_block] = subnet
      end
      return subnets
    end

    def self.get_ami(puke_config, instance_type, family)
      if Vominator::EC2.get_virt_type(instance_type) == 'hvm'
        ami = puke_config['linux_hvm_base_image'] if family == 'linux'
        ami = puke_config['windows_hvm_base_image'] if family == 'windows'
      else
        ami = puke_config['linux_paravirtual_base_image'] if family == 'linux'
        ami = puke_config['windows_paravirtual_base_image'] if family == 'windows'
      end
      return ami
    end

    def self.create_subnet(resource, subnet, az, vpc_id)
      subnet = resource.vpcs(filters: [{name: 'vpc-id', values: [vpc_id]}]).first.create_subnet(:cidr_block => subnet, :availability_zone => az)
      return subnet
    end

    def self.get_termination_protection(client, instance_id)
      return client.describe_instance_attribute(:instance_id => instance_id, :attribute => 'disableApiTermination').disable_api_termination.value
    end

    def self.set_termination_protection(client, instance_id, state)
      client.modify_instance_attribute(:instance_id => instance_id, :disable_api_termination => { :value => state })
      return client.describe_instance_attribute(:instance_id => instance_id, :attribute => 'disableApiTermination').disable_api_termination.value
    end

    def self.get_instance_state(resource, instance_id)
      instance = Vominator::EC2.get_instance(resource,instance_id)

      return instance.state.name
    end

    def self.set_instance_type(resource, instance_id, type, fqdn)
      instance = Vominator::EC2.get_instance(resource,instance_id)
      instance.stop

      # TODO: Add a timed break?
      sleep 5 until Vominator::EC2.get_instance_state(resource, instance_id) == 'stopped'
      instance.modify_attribute(:attribute => 'instanceType', :value => type)

      # TODO: We should add in a sleep (with a timed break) and verify the instance goes back to running
      begin
        instance.start
      rescue Aws::EC2::Errors::Unsupported
        LOGGER.warning("Disabling EBS Optimization for #{fqdn} because #{type} does not support this functionality")
        instance.ebs_optimized = false
        instance.start
      end
      return Vominator::EC2.get_instance(resource,instance_id).instance_type
    end


    def self.allocate_public_ip(client, domain='vpc')
      return client.allocate_address(domain: domain)
    end

    def self.assign_public_ip(client, instance_id)
      eip = client.allocate_address(:domain => 'vpc')
      tries ||= 3
      begin
        sleep(0.25)
        association = client.associate_address(:instance_id => instance_id, :allocation_id => eip.allocation_id)
      rescue Aws::EC2::Errors::InvalidAllocationIDNotFound
        retry unless (tries -= 1).zero?
      end

      if association
        return eip.public_ip
      else
        return nil
      end
    end

    def self.remove_public_ip(client, instance_id)
      allocation_id = client.describe_addresses(filters: [{name: 'instance-id', values: [instance_id]}]).first['addresses'].first['association_id']
      if client.disassociate_address(:association_id => allocation_id)
        return true
      else
        return false
      end
    end

    def self.set_ebs_optimized(resource, instance_id, state, fqdn)
      instance = Vominator::EC2.get_instance(resource,instance_id)
      instance.stop

      # TODO: Add a timed break?
      sleep 5 until Vominator::EC2.get_instance_state(resource, instance_id) == 'stopped'

      # TODO: We should add in a sleep (with a timed break) and verify the instance goes back to running
      begin
        instance.modify_attribute(:ebs_optimized => {:value => state})
        instance.start
        return state
      rescue Aws::EC2::Errors::Unsupported
        LOGGER.error("#{fqdn} does not support setting EBS Optimization to #{state} as this is not supported for #{instance.instance_type}")
        instance.modify_attribute(:ebs_optimized => {:value => false})
        instance.start
        return instance.ebs_optimized
      end
    end

    def self.set_source_dest_check(resource, instance_id, state)
      instance = Vominator::EC2.get_instance(resource,instance_id)
      if instance.modify_attribute(:source_dest_check => {:value => state})
        return state
      end
    end

    def self.set_security_groups(resource, instance_id, security_groups, vpc_security_groups, append=true)
      instance = Vominator::EC2.get_instance(resource,instance_id)
      if append
        security_groups = security_groups + instance.security_groups.map {|sg| sg[:group_name]}
      end
      group_ids = security_groups.map { |sg| vpc_security_groups[sg] }
      instance.modify_attribute(:groups => group_ids.compact)
      return Vominator::EC2.get_instance(resource,instance_id).security_groups.map {|sg| sg[:group_name]}
    end

    def self.get_ebs_volume(resource, ebs_volume_id)
      return resource.volumes(filters: [{name: 'volume-id', values: [ebs_volume_id]}]).first
    end

    def self.get_instance_ebs_volumes(resource, instance_id)
      instance = Vominator::EC2.get_instance(resource,instance_id)
      return instance.block_device_mappings.map {|vol| vol[:device_name]}
    end

    def self.add_ebs_volume(resource, instance_id, volume_type, volume_size, mount_point, iops=false, encrypted=false)
      instance = Vominator::EC2.get_instance(resource,instance_id)
      availability_zone = instance.placement[:availability_zone]

      case volume_type
      when 'magnetic'
        volume = resource.create_volume(:availability_zone => availability_zone, :volume_type => 'standard', :size => volume_size, :encrypted => encrypted)
      when 'gp'
        volume = resource.create_volume(:availability_zone => availability_zone, :volume_type => 'gp2', :size => volume_size, :encrypted => encrypted)
      when 'piops'
        iops = volume_size * 15 unless iops
        volume = resource.create_volume(:availability_zone => availability_zone, :volume_type => 'io1', :size => volume_size, :iops => iops, :encrypted => encrypted)
      else
        volume = nil
        LOGGER.fatal("#{volume_type} is unsupported")
      end
      LOGGER.info("Waiting for #{volume.id} to be provisioned and become available")

      sleep 3 until Vominator::EC2.get_ebs_volume(resource, volume.id).state == 'available'

      LOGGER.info("Attaching #{volume.id} to the instance and waiting for it to be attached.")
      instance.attach_volume(:device => mount_point, :volume_id => volume.id)
      sleep 3 until Vominator::EC2.get_ebs_volume(resource, volume.id).state == 'in-use'

      return volume
    end

    def self.get_ephemeral_devices(instance_type)
      device_count = Vominator::EC2.get_ephemeral_dev_count(instance_type)
      devices = Hash.new
      for i in 1..device_count
        mount_point = (65 + (i)).chr.downcase
        devices["/dev/sd#{mount_point}"] = "ephemeral#{i-1}"
      end
      return devices
    end

    def self.create_instance(resource, hostname, environment, ami_id, subnet_id, instance_type, key_name, private_ip_address, az, security_group_ids, user_data, ebs_optimized, iam_profile)
      begin
        LOGGER.info("Creating instance for #{hostname}.#{environment}")
        instance = resource.create_instances(:min_count => 1, :max_count => 1, :image_id => ami_id, :subnet_id => subnet_id, :instance_type => instance_type, :key_name => key_name, :private_ip_address => private_ip_address, :placement => {:availability_zone => az}, :security_group_ids => security_group_ids, :user_data => Base64.encode64(user_data), :ebs_optimized => ebs_optimized, :iam_instance_profile => {:name => iam_profile}).first
      rescue Aws::EC2::Errors::InvalidIPAddressInUse
        LOGGER.fatal("Unable to create the instance as #{private_ip_address} is in use")
      rescue Aws::EC2::Errors::InternalError
        LOGGER.fatal("Unable to create instance due to an AWS internal server error. Try again in a bit")
      end
      LOGGER.info('Waiting for the instance to come online.')
      sleep 10
      sleep 2 until Vominator::EC2.get_instance_state(resource, instance.id) != 'pending'

      instance.create_tags(:tags => [{:key => 'Name', :value => "#{hostname}.#{environment}"},{:key => 'Environment', :value => environment},{:key => 'Provisioned_By', :value => 'Vominator'}])

      if Vominator::EC2.get_instance_state(resource, instance.id) == 'running'
        return instance
      else
        return nil
      end
    end

    def self.terminate_instance(resource, instance_id)
      instance = Vominator::EC2.get_instance(resource,instance_id)
      instance.terminate
      sleep 2 until Vominator::EC2.get_instance_state(resource, instance.id) == 'terminated'
      return true
    end

    def self.tag_resource(client, resource_id, tags)
      client.create_tags(resources: [resource_id], tags: tags)
    end

    def self.get_security_groups(client, vpc_id)
      return client.describe_security_groups(filters: [{name: 'vpc-id', values: [vpc_id]}]).first.security_groups
    end

    def self.create_security_group(client, name, vpc_id, description=nil)
      return client.create_security_group(group_name: name, description: description || name, vpc_id: vpc_id)
    end

    def self.create_security_group_rule(client,type,group_id,rule)
      case type
        when 'ingress'
          if rule[:source_security_group_id]
            client.authorize_security_group_ingress({group_id: group_id, ip_permissions: [{ip_protocol: rule[:ip_protocol], from_port: rule[:from_port], to_port: rule[:to_port], user_id_group_pairs: [{group_id: rule[:source_security_group_id]}]}]})
          end

          if rule[:cidr_ip]
            client.authorize_security_group_ingress({group_id: group_id, cidr_ip: rule[:cidr_ip], ip_protocol: rule[:ip_protocol], from_port: rule[:from_port], to_port: rule[:to_port]})
          end

        when 'egress'
          if rule[:source_security_group_id]
            client.authorize_security_group_egress({group_id: group_id, ip_permissions: [{ip_protocol: rule[:ip_protocol], from_port: rule[:from_port], to_port: rule[:to_port], user_id_group_pairs: [{group_id: rule[:source_security_group_id]}]}]})
          end

          if rule[:cidr_ip]
            client.authorize_security_group_egress({group_id: group_id, cidr_ip: rule[:cidr_ip], ip_protocol: rule[:ip_protocol], from_port: rule[:from_port], to_port: rule[:to_port]})
          end
        else
          return false
      end
    end

    def self.delete_security_group_rule(client,type,group_id,rule)
      case type
        when 'ingress'
          if rule[:source_security_group_id]
            client.revoke_security_group_ingress({group_id: group_id, ip_permissions: [{ip_protocol: rule[:ip_protocol], from_port: rule[:from_port], to_port: rule[:to_port], user_id_group_pairs: [{group_id: rule[:source_security_group_id]}]}]})
          end
      
          if rule[:cidr_ip]
            client.revoke_security_group_ingress({group_id: group_id, ip_permissions: [{ip_protocol: rule[:ip_protocol], from_port: rule[:from_port], to_port: rule[:to_port], ip_ranges: [{cidr_ip: rule[:cidr_ip]}]}]})
          end
    
        when 'egress'
          if rule[:source_security_group_id]
            client.revoke_security_group_egress({group_id: group_id, ip_permissions: [{ip_protocol: rule[:ip_protocol], from_port: rule[:from_port], to_port: rule[:to_port], user_id_group_pairs: [{group_id: rule[:source_security_group_id]}]}]})
          end
      
          if rule[:cidr_ip]
            client.revoke_security_group_egress({group_id: group_id, ip_permissions: [{ip_protocol: rule[:ip_protocol], from_port: rule[:from_port], to_port: rule[:to_port], ip_ranges: [{cidr_ip: rule[:cidr_ip]}]}]})
          end
        else
          return false
      end
    end
  end
end
