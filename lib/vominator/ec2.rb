require 'aws-sdk'
require './constants.rb'

module Vominator
  class EC2
    def self.get_virt_type(instance_type)
      return EC2_INSTANCE_METADATA[instance_type.to_sym][:virtualization_type]
    end

    def self.get_ephemeral_dev_count(instance_type)
      return EC2_INSTANCE_METADATA[instance_type.to_sym][:ephemeral_devices]
    end

    def self.get_instances(resource)
      resource.instances
    end

    def self.get_security_groups(resource)

    end

    def self.get_subnets(resource)

    end
  end
end
