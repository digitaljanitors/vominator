require 'yaml'
require 'colored'
require 'highline/import'
require_relative 'version'

module Vominator
  def self.get_config(file='~/.vominator.yaml')
    config_file = ENV['VOMINATOR_CONFIG'] || File.expand_path(file)
    if File.exist?(config_file)
      vominator_config = YAML.load(File.read(config_file))
      return vominator_config if vominator_config.kind_of?(Hash)
    else
      #TODO: This should instead raise an error.
      return false
    end
  end

  def self.get_puke_config(puke_dir)
    if File.exist?(puke_dir)
      config_file = "#{puke_dir}/config.yaml"
      puke_config = YAML.load(File.read(config_file))
    else
      raise("Unable to open puke configuration at #{puke_dir}")
    end
    return puke_config if puke_config.kind_of?(Hash)
  end

  def self.get_key_pair(vominator_config)
    return vominator_config['key_pair_name']
  end

  def self.get_puke_variables(environment)
    data = PUKE_CONFIG[environment]
    return data
  end

  def self.yesno?(prompt: 'Continue?', default: true)
    a = ''
    s = default ? '[Y/n]' : '[y/N]'
    d = default ? 'y' : 'n'
    until %w[y n].include? a
      a = ask("#{prompt} #{s} ") { |q| q.limit = 1; q.case = :downcase }
      a = d if a.length == 0
    end
    a == 'y'
  end

  class Logger
    def self.info(message)
      puts message
    end

    def self.test(message)
      puts message.cyan
    end

    def self.error(message)
      puts message.red
    end

    def self.fatal(message)
      puts message.red
      exit(1)
    end

    def self.success(message)
      puts message.green
    end

    def self.warning(message)
      puts message.yellow
    end
  end
end
