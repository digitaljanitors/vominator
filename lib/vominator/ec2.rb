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

    def self.get_ami(puke_config, instance_type, os)
      if Vominator::EC2.get_virt_type(instance_type) == 'hvm'
        ami = puke_config['linux_hvm_base_image'] if os == 'linux'
        ami = puke_config['windows_hvm_base_image'] if os == 'windows'
      else
        ami = puke_config['linux_paravirtual_base_image'] if os == 'linux'
        ami = puke_config['windows_paravirtual_base_image'] if os == 'windows'
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
  end
end
