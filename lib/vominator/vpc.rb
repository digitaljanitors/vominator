require 'aws-sdk'
require_relative 'constants'

module Vominator
  class VPC
    def self.get_vpc(client, vpc_id)
      return client.describe_vpcs(filters: [{name: 'vpc-id', values: [vpc_id]}]).vpcs.first
    end
    def self.get_vpc_by_cidr(client, cidr_block)
      return client.describe_vpcs(filters: [{name: 'cidr', values: [cidr_block]}]).vpcs.first
    end

    def self.create_vpc(client, cidr_block, tenancy='default')
      resp = client.create_vpc(:cidr_block => cidr_block, :instance_tenancy => tenancy)
      sleep 2 until Vominator::VPC.get_vpc(client,resp.vpc.vpc_id).state == 'available'
      return resp.vpc
    end

    def self.get_internet_gateway(client, gateway_id)
      return client.describe_internet_gateways(filters: [{name: 'internet-gateway-id', values: [gateway_id]}]).internet_gateways.first
    end

    def self.create_internet_gateway(client)
      resp = client.create_internet_gateway
      return resp.internet_gateway      
    end

    def self.attach_internet_gateway(client, gateway_id, vpc_id)
      resp = client.attach_internet_gateway(internet_gateway_id: gateway_id, vpc_id: vpc_id)
      sleep 2 until Vominator::VPC.get_internet_gateway(client, gateway_id).attachments.first.state == 'available'
      return true
    end

    def self.get_nat_gateway(client, gateway_id)
      return client.describe_nat_gateways(filter: [{name: 'nat-gateway-id', values: [gateway_id]}]).nat_gateways.first
    end
   
    def self.create_nat_gateway(client, subnet_id, allocation_id)
      resp = client.create_nat_gateway(subnet_id: subnet_id, allocation_id: allocation_id).nat_gateway
      sleep 2 until Vominator::VPC.get_nat_gateway(client, resp.nat_gateway_id).state == 'available'
      return resp
    end
 
    def self.get_route_tables(client, vpc_id)
      return client.describe_route_tables(filters: [{name: 'vpc-id', values: [vpc_id]}]).route_tables
    end

    def self.get_route_table(client, route_table_id)
      return client.describe_route_tables(filters: [{name: 'route-table-id', values: [route_table_id]}]).route_tables.first
    end

    def self.create_internet_gateway_route(client, route_table_id, destination_cidr_block, gateway_id)
      return client.create_route(route_table_id: route_table_id, destination_cidr_block: destination_cidr_block, gateway_id: gateway_id)
    end

    def self.create_nat_gateway_route(client, route_table_id, destination_cidr_block, nat_gateway_id)
      return client.create_route(route_table_id: route_table_id, destination_cidr_block: destination_cidr_block, nat_gateway_id: nat_gateway_id)
    end

    def self.create_route_table(client, vpc_id)
      resp = client.create_route_table(vpc_id: vpc_id).route_table
      sleep 2 until Vominator::VPC.get_route_table(client, resp.route_table_id)
      return resp
    end

    def self.get_subnet(client, subnet_id)
      return client.describe_subnets(filters: [{name: 'subnet-id', values: [subnet_id]}]).subnets.first
    end

    def self.create_subnet(client, vpc_id, cidr_block, availability_zone)
      resp = client.create_subnet(vpc_id: vpc_id, cidr_block: cidr_block, availability_zone: availability_zone).subnet
      sleep 2 until Vominator::VPC.get_subnet(client, resp.subnet_id).state == 'available'
      return resp
    end

    def self.associate_route_table(client, subnet_id, route_table_id)
      return client.associate_route_table(subnet_id: subnet_id, route_table_id: route_table_id)
    end

    
  end
end
