require_relative 'constants'
require 'erubis'

module Vominator
  class Instances
    def self.get_instances(environment, product, filter=false)
      if PUKE_CONFIG[environment]['products'].include? product
        config_file = File.expand_path("#{VOMINATOR_CONFIG['configuration_path']}/products/#{product}/instances.yaml")
        if filter
          instances = Array.new
          YAML.load(File.read(config_file)).each do |instance|
            if filter.include? instance.keys[0]
              instances.push instance
            end
          end
        else
          instances = YAML.load(File.read(config_file))
        end
        return instances if instances.kind_of?(Array)
      end
    end

    def self.generate_cloud_config(hostname, environment, chef_environment, family, roles, recipes)
      template = "#{family}_cloud_config_template"
      begin
        cloud_config_template = File.read("#{VOMINATOR_CONFIG['configuration_path']}/cloud-configs/#{PUKE_CONFIG[environment][template]}")
      rescue Errno::EISDIR
        LOGGER.fatal("Unable to find #{template} in your cloud-config directory. Check that this file exists in #{VOMINATOR_CONFIG['configuration_path']}/cloud-configs/")
      end
      cloud_config = Erubis::Eruby.new(cloud_config_template)
      return cloud_config.result(:hostname => hostname, :env => environment, :chef_env => chef_environment, :roles => roles, :recipes => recipes)
    end
  end
end
