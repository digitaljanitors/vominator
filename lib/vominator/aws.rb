require 'aws-sdk'
require_relative 'vominator'
require_relative 'constants'

Aws.config[:credentials] = Aws::Credentials.new(VOMINATOR_CONFIG['access_key_id'], VOMINATOR_CONFIG['secret_access_key'])

module Vominator
  class AWS
    def self.get_availability_zones(ec2_client)
      resp = ec2_client.describe_availability_zones
      zones = resp.availability_zones.map{|z| z['zone_name']}.sort_by{|z| z}
      return zones
    end
  end
end