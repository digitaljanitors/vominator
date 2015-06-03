require_relative 'constants'

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
  end
end
