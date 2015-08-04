require 'aws-sdk'
require_relative 'constants'

module Vominator
  class Route53
    def self.get_records(client, zone, max_items=50)
      resp = client.list_resource_record_sets(:hosted_zone_id => zone, :max_items => max_items)
      records = resp[:resource_record_sets]
      while resp[:is_truncated]
        resp = client.list_resource_record_sets(:hosted_zone_id => zone, :max_items => max_items, :start_record_name => resp[:next_record_name])
        records += resp[:resource_record_sets]
      end
      names = Array.new
      records.each do |record|
        names.push record[:name]
      end
      return names
    end

    def self.create_record(client, zone, fqdn, ip, type='A', ttl=600)
      resp = client.change_resource_record_sets(
          :hosted_zone_id => "/hostedzone/#{zone}",
          :change_batch => {
              :changes => [
                  {
                      :action => "CREATE",
                      :resource_record_set => {
                          :name => "#{fqdn}.",
                          :type => type,
                          :ttl => ttl,
                          :resource_records => [{
                                                    :value => "#{ip}"
                                                }]
                      }
                  }
              ]
          }
      )

      if resp.change_info.status == 'PENDING'
        return true
      else
        return false
      end
    end

    def self.delete_record(client, zone, fqdn, ip, type='A', ttl=600)
      resp = client.change_resource_record_sets(
          :hosted_zone_id => "/hostedzone/#{zone}",
          :change_batch => {
              :changes => [
                  {
                      :action => "DELETE",
                      :resource_record_set => {
                          :name => "#{fqdn}.",
                          :type => type,
                          :ttl => ttl,
                          :resource_records => [{
                                                    :value => ip
                                                }]
                      }

                  }
              ]
          }
      )
      if resp.change_info.status == 'PENDING'
        return true
      else
        return false
      end
    end

  end
end
