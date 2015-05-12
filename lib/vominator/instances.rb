require './constants.rb'

module Vominator
  class Instances
    def self.get_instances(environment,product)
      if PUKE_CONFIG[environment]['products'].include? product
        config_file = File.expand_path("#{VOMINATOR_CONFIG['configuration_path']}/instances/#{product}.yaml")
        instances = YAML.load(File.read(config_file))
        return instances if instances.kind_of?(Array)
      end
    end
  end
end