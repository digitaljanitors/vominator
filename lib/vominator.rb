require 'yaml'
require 'colorize'
require "vominator/version"

module Vominator
  def self.get_config
    config_file = File.expand_path("~/.vominator.yaml")
    vominator_config = YAML.load(File.read(config_file))
    return vominator_config if vominator_config.kind_of?(Hash)
  end

  def self.get_puke_config(puke_dir)
    config_file = "#{puke_dir}/config.yaml"
    puke_config = YAML.load(File.read(config_file))
    return puke_config if puke_config.kind_of?(Hash)
  end

  class Logger
    def self.info(message)
      return message
    end

    def self.error(message)
      return message.red
    end

    def self.success(message)
      return message.green
    end
  end
end
