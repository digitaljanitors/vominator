require 'aws-sdk'

require './vominator.rb'

Aws.config[:credentials] = Aws::Credentials.new(VOMINATOR_CONFIG['access_key_id'], VOMINATOR_CONFIG['secret_access_key'])

module Vominator
  class AWS
    def self.get_virt_type(instance_type)
      return EC2_INSTANCE_METADATA[instance_type.to_sym][:virtualization_type]
    end

    def self.get_ephemeral_dev_count(instance_type)
      return EC2_INSTANCE_METADATA[instance_type.to_sym][:ephemeral_devices]
    end
  end
end
