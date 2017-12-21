require 'net/http'
require 'uri'
require 'json'
require_relative 'constants'

module Vominator
  module EC2Info
    def get(type)
      InstanceInfo.new().get_instance(type)
    end
    module_function :get

    class InstanceInfo
      # The URI to JSON data from ec2instances.info
      @@uri = URI.parse('https://www.ec2instances.info/instances.json')
      @@instances = nil

      attr_accessor :filepath
      attr_accessor :instances

      def initialize(file=nil)
        self.filepath = file || filepath_from_config

        # Get the source file from @@uri if it's too old or missing
        get_instance_info if refresh_info?

        # Load the json data
        load_instances()
      end

      def get_instance(type)
        Instance.new(@@instances.detect {|i| i['instance_type'] == type})
      end

      def load_instances()
        get_instance_info() if refresh_info?
        
        instances = JSON.load(File.read(self.filepath))
        @@instances = instances if instances.kind_of?(Array)
      end

      def refresh_info?
        return true if not File.exist?(self.filepath) or File.zero?(self.filepath)
        last_modified = Net::HTTP.start(@@uri.hostname, @@uri.port,
                        :use_ssl => @@uri.scheme == 'https') { |http|
           http.request(Net::HTTP::Head.new(@@uri.request_uri))['last-modified'] }
        Time.parse(last_modified) > File.ctime(self.filepath)
      end

      def get_instance_info()
        File.open(self.filepath, 'w+') { |f| f.write(Net::HTTP.get(@@uri)) }
      end

      def filepath_from_config
        file = VOMINATOR_CONFIG['instances_file']
        if File.exist?(file)
          file = File.expand_path(file)
        end
        file
      end

      private :filepath_from_config
    end

    class Instance
      attr_accessor :raw

      def initialize(instance={})
        self.raw = instance
      end

      def ephemeral_devices
        device_count = if not self.raw['storage'].nil? and self.raw['storage'].key? 'devices'
          self.raw['storage']['devices']
        else 0
        end
      end

      def virtualization_type
        vt = case
        when self.raw['linux_virtualization_types'].include?('HVM'), 
             self.generation.eql?('current'),
             self.instance_type.start_with?('cc2'),
             self.instance_type.start_with?('hi1'),
             self.instance_type.start_with?('hs1'),
             self.instance_type.start_with?('cr1')
          'hvm'
        else
          'paravirtual'
        end
      end


      def method_missing(name)
        self.raw[name.to_s] if self.raw.key? name.to_s
      end
    end
  end
end
