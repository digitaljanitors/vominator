require 'aws-sdk'
require_relative 'constants'

module Vominator
  class EC2
    def self.get_virt_type(instance_type)
      return EC2_INSTANCE_METADATA[instance_type.to_sym][:virtualization_type]
    end

    def self.get_ephemeral_dev_count(instance_type)
      return EC2_INSTANCE_METADATA[instance_type.to_sym][:ephemeral_devices]
    end

    def self.get_instances(resource)
      # filter this to just what we need.
      resource.instances
    end

    def self.get_instance(resource, instance_id)
      return resource.instances(filters: [{name: 'instance-id', values: [instance_id]}]).first
    end

    def self.get_security_groups(resource, vpc_id)
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
  end
end
