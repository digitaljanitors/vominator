require 'aws-sdk'
require_relative 'constants'

module Vominator
  class Route53
    def self.get_zone_by_id(client, zone_id)
      return client.get_hosted_zone(id: zone_id).hosted_zone
    end

    def self.get_zone_by_domain(client, domain_name)
      zones = client.list_hosted_zones_by_name(dns_name: domain_name).hosted_zones
      zone = nil
      zones.each do |z|
        zone = z if z.name == "#{domain_name}."
      end

      return zone
    end

    def self.create_zone(client, domain_name)
      return client.create_hosted_zone(name: domain_name, caller_reference: "#{domain_name} + #{Time.now.to_i}")
    end

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

    def self.create_nameserver_records(client, zone, fqdn, nameservers, ttl=172800)
      resource_records = Array.new
      nameservers.each do |nameserver|
        hash = Hash.new
        hash[:value] = nameserver
        resource_records.push hash
      end

      resp = client.change_resource_record_sets(
          :hosted_zone_id => zone,
          :change_batch => {
              :changes => [
                  {
                      :action => "CREATE",
                      :resource_record_set => {
                          :name => fqdn,
                          :type => 'NS',
                          :ttl => ttl,
                          :resource_records => resource_records
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

    def self.create_record(client, zone, fqdn, ip, type='A', ttl=600)
      resp = client.change_resource_record_sets(
          :hosted_zone_id => zone,
          :change_batch => {
              :changes => [
                  {
                      :action => "CREATE",
                      :resource_record_set => {
                          :name => fqdn,
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
  end
end
