require 'aws-sdk'
require 'vominator/constants'

module Vominator
  class Route53
    def self.get_records(client, zone)
      resp = client.list_resource_record_sets(:hosted_zone_id => zone, :max_items => 50)
      records = resp[:resource_record_sets]
      while resp[:is_truncated]
        resp = client.list_resource_record_sets(:hosted_zone_id => zone, :max_items => 50, :start_record_name => resp[:next_record_name])
        records += resp[:resource_record_sets]
      end
      names = Array.new
      records.each do |record|
        names.push record[:name]
      end
      return names
    end
  end
end
