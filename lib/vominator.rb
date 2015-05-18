require 'yaml'
require 'colorize'
require 'highline/import'
require 'vominator/version'

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


  def self.get_puke_variables(environment)
    data = PUKE_CONFIG[environment]
    return data
  end

  def self.yesno(prompt = 'Continue?', default = true)
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
      puts message.green
    end
  end
end
