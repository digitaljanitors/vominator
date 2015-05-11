require 'yaml'
require "vominator/version"

module Vominator
  def self.get_config
    config_file = File.expand_path("~/.vominator.yml")
    vominator_config = YAML.load(File.read(config_file))
    return vominator_config if vominator_config.kind_of?(Hash)
  end
end
