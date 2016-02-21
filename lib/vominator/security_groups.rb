require 'aws-sdk'
require_relative 'vominator'
require_relative 'constants'

module Vominator
  class SecurityGroups
    def self.get_security_groups(environment, product, filter=false)
      if PUKE_CONFIG[environment]['products'].include? product
        config_file = File.expand_path("#{VOMINATOR_CONFIG['configuration_path']}/products/#{product}/security_groups.yaml")
        if filter
          security_groups = Array.new
          YAML.load(File.read(config_file)).each do |security_group|
            if filter.include? security_group.keys[0]
              security_groups.push security_group
            end
          end
        else
          security_groups = YAML.load(File.read(config_file))
        end
        return security_groups if security_groups.kind_of?(Array)
      end
    end  
  end
end
