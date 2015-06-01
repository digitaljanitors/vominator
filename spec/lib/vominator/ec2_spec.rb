require 'spec_helper'
require 'vominator/ec2'
require 'pry'
describe Vominator::EC2 do

  before(:all) do
    @puke_variables = Vominator.get_puke_variables('test')
    Aws.config[:stub_responses] = true
    @ec2_client = Aws::EC2::Client.new
    @ec2_client.stub_responses(:describe_vpcs, :next_token => nil, :vpcs => [
      {
          :vpc_id => 'vpc-ada2d4c8',
          :cidr_block => '10.203.0.0/16'
      }
    ])
    @ec2_client.stub_responses(:describe_subnets, :next_token => nil, :subnets => [
      {
          :subnet_id => 'sub-11111',
          :vpc_id => 'vpc-ada2d4c8',
          :cidr_block => '10.203.41.0/24',
          :availability_zone => 'us-east-1c'
      },
      {
          :subnet_id => 'sub-11112',
          :vpc_id => 'vpc-ada2d4c8',
          :cidr_block => '10.203.42.0/24',
          :availability_zone => 'us-east-1d'
      },
      {
          :subnet_id => 'sub-11113',
          :vpc_id => 'vpc-ada2d4c8',
          :cidr_block => '10.203.43.0/24',
          :availability_zone => 'us-east-1e'
      }
    ])
    @ec2_client.stub_responses(:describe_instances, :next_token => nil, :reservations => [
      {
        :reservation_id => 'r-567b402e',
        :owner_id => '012329383471727',
        :groups => [],
        :instances => [{
          :instance_id => 'i-1968d168',
          :vpc_id => 'vpc-ada2d4c8',
          :key_name => 'ci@example.com',
          :instance_type => 'm3.medium',
          :private_ip_address => '10.203.41.21',
          :virtualization_type => 'hvm',
          :architecture => 'x86_64',
          :source_dest_check => false,
          :ebs_optimized => false,
          :tags => [{:key => 'Name', :value => 'sample-api-1.test'}],
          :placement => {:availability_zone => 'us-east-1c'}
          }]
      },
      {
        :reservation_id => 'r-7013f428',
        :owner_id => '012329383471727',
        :groups => [],
        :instances => [{
           :instance_id => 'i-1766874c',
           :vpc_id => 'vpc-ada2d4c8',
           :key_name => 'ci@example.com',
           :instance_type => 'm3.medium',
           :private_ip_address => '10.203.42.21',
           :virtualization_type => 'hvm',
           :architecture => 'x86_64',
           :source_dest_check => false,
           :ebs_optimized => false,
           :tags => [{:key => 'Name', :value => 'sample-api-2.test'}],
           :placement => {:availability_zone => 'us-east-1d'}
       }]
      },
      {
        :reservation_id => 'r-b274d2f4',
        :owner_id => '012329383471727',
        :groups => [],
        :instances => [{
           :instance_id => 'i-1b68d16a',
           :vpc_id => 'vpc-ada2d4c8',
           :key_name => 'ci@example.com',
           :instance_type => 'm3.medium',
           :private_ip_address => '10.203.43.21',
           :virtualization_type => 'hvm',
           :architecture => 'x86_64',
           :source_dest_check => false,
           :ebs_optimized => false,
           :tags => [{:key => 'Name', :value => 'sample-api-3.test'}],
           :placement => {:availability_zone => 'us-east-1e'}
       }]
      }
    ])
    @ec2_client.stub_responses(:describe_security_groups, :next_token => nil, :security_groups => [
      {
          :vpc_id => 'vpc-ada2d4c8',
          :owner_id => '012329383471727',
          :group_id => 'sg-11111',
          :group_name => 'test-sample-api-load-balancer',
          :description => 'test-sample-api-load-balancer',
          :ip_permissions => [
              {
                  :ip_protocol => 'tcp',
                  :from_port => 80,
                  :to_port => 80,
                  :ip_ranges => [
                      {
                          :cidr_ip => '0.0.0.0/0'
                      }
                  ]
              }
          ],
          :ip_permissions_egress => [
              {
                  :ip_protocol => 'tcp',
                  :from_port => 8080,
                  :to_port => 8080,
                  :user_id_group_pairs => [
                      {
                          :group_name => 'test-sample-api-server',
                          :group_id => 'sg-11112'
                      }
                  ]
              }
          ]
      },
      {
          :vpc_id => 'vpc-ada2d4c8',
          :owner_id => '012329383471727',
          :group_id => 'sg-11112',
          :group_name => 'test-sample-api-server',
          :description => 'test-sample-api-server',
          :ip_permissions => [
              {
                  :ip_protocol => 'tcp',
                  :from_port => 8080,
                  :to_port => 8080,
                  :user_id_group_pairs => [
                      {
                          :group_name => 'test-sample-api-load-balancer',
                          :group_id => 'sg-11111'
                      }
                  ]
              }
          ],
          :ip_permissions_egress => [
          ]
      }
    ])
    @ec2 = Aws::EC2::Resource.new(client: @ec2_client)
  end

  describe 'get_virt_type' do
    context 'when I pass a valid instance_type' do
      let (:instance_type) {Vominator::EC2.get_virt_type('m3.medium')}

      subject { instance_type }
      # TODO: We should probably test all instance types here.
      it 'returns the appropriate instance type' do
        expect { instance_type }.to_not raise_error
        expect(instance_type).to match('hvm')
      end
    end

    context 'when I pass an invalid instance type' do
      let (:instance_type) {Vominator::EC2.get_virt_type('invalid_instance_type')}

      subject { instance_type }

      xit 'should do something' do

      end
    end
  end

  describe 'get_ephemeral_dev_count' do
    context 'when I pass a valid instance_type' do
      let (:ephemeral_dev_count) { Vominator::EC2.get_ephemeral_dev_count('m3.medium')}

      subject { ephemeral_dev_count }

      # TODO: We should probably test all instance types here.
      it 'returns the appropriate number of ephemeral devices' do
        expect { ephemeral_dev_count }.to_not raise_error
        expect(ephemeral_dev_count).to match(1)
      end
    end

    context 'when I pass an invalid instance type' do
      let (:ephemeral_dev_count) { Vominator::EC2.get_ephemeral_dev_count('invalid_instance_type')}

      subject { ephemeral_dev_count }

      xit 'should do something'

    end
  end

  describe 'get_instances' do
    context 'when I pass a valid ec2 resource' do
      let (:instances) { Vominator::EC2.get_instances(@ec2) }

      subject { instances }

      it 'should return ec2 instances' do
        expect {instances}.to_not raise_error
        expect(instances.count).to eq 3
        # TODO: Maybe something that checks we got back the expected instances?
      end
    end

    context 'when I pass an invalid ec2 resource' do

      xit 'do something' do

      end

    end
  end

  describe 'get_instance' do
    context 'when I pass a valid ec2 resource and a valid instance ID' do
      let (:instance) { Vominator::EC2.get_instance(@ec2, 'i-1968d168')}

      subject { instance }

      it 'should return an ec2 instance object' do
        expect {instance}.to_not raise_error
        expect(instance.id).to match 'i-1968d168'
        expect(instance.private_ip_address).to match '10.203.41.21'
      end
    end

    context 'when I pass an invalid ec2 resource or invalid instance ID.' do
      xit 'do something'
    end
  end

  describe 'get_security_groups' do
    context 'when I pass a valid resource and vpc_id' do
      let (:security_groups) { Vominator::EC2.get_security_groups(@ec2, @puke_variables['vpc_id'])}

      subject { security_groups }

      it 'should return all security groups for the vpc' do
        expect { security_groups }.to_not raise_error
        expect(security_groups.count).to eq 2
        expect(security_groups['test-sample-api-load-balancer']).to eq 'sg-11111'
        expect(security_groups['test-sample-api-server']).to eq 'sg-11112'
      end
    end

    context 'when I pass an invalid resource or vpc_id' do
      xit 'do something'
    end
  end

  describe 'get_subnets' do
    context 'when I pass a valid resource and vpc_id' do
      let (:subnets) { Vominator::EC2.get_subnets(@ec2, @puke_variables['vpc_id'])}

      subject { subnets }

      it 'should return all subnets for the vpc' do
        expect { subnets }.to_not raise_error
        expect(subnets.count).to eq 3
        expect(subnets['10.203.41.0/24'].id).to match 'sub-11111'
        expect(subnets['10.203.42.0/24'].id).to match 'sub-11112'
        expect(subnets['10.203.43.0/24'].id).to match 'sub-11113'
      end
    end

    context 'when I pass an invalid resource or vpc_id' do
      xit 'do something'
    end
  end

  describe 'get_ami' do
    context 'when I pass a valid puke_config, HVM instance type, and linux as the os' do
      let (:ami) { Vominator::EC2.get_ami(@puke_variables, 'm3.medium', 'linux')}

      subject {ami}

      it 'should return a linux ami for an HVM Instance.' do
        expect { ami }.to_not raise_error
        expect(ami).to match('ami-260d074e')
      end
    end

    context 'when I pass a valid puke_config, paravirtual instance type, and linux as the os' do
      let (:ami) { Vominator::EC2.get_ami(@puke_variables, 't1.micro', 'linux')}

      subject {ami}

      it 'should return a linux ami for an Paravirtual Instance.' do
        expect { ami }.to_not raise_error
        expect(ami).to match('ami-280d0740')
      end
    end

    context 'when I pass a valid puke_config, HVM instance type, and windows as the os' do
      let (:ami) { Vominator::EC2.get_ami(@puke_variables, 'm3.medium', 'windows')}

      subject {ami}

      it 'should return a linux ami for an HVM Instance.' do
        expect { ami }.to_not raise_error
        expect(ami).to match('ami-9231e2fa')
      end
    end

    context 'when I pass a valid puke_config, paravirtual instance type, and windows as the os' do
      let (:ami) { Vominator::EC2.get_ami(@puke_variables, 't1.micro', 'windows')}

      subject {ami}

      it 'should return a linux ami for an Paravirtual Instance.' do
        expect { ami }.to_not raise_error
        expect(ami).to match('ami-78bce2lm')
      end
    end

    context 'when I pass an invalid puke_config, instance_type or os' do
      xit 'do something'
    end
  end

  describe 'create_subnet' do
    context 'when I pass a valid resource, subnet, az, and vpc_id' do
      let (:subnet) { Vominator::EC2.create_subnet(@ec2, '10.203.21.0/24', 'us-east-1a', @puke_variables['vpc_id'])}

      subject { subnet }

      xit 'should return a subnet object' do
        expect { subnet }.to_not raise_error
        # TODO: How do we verify that this actually worked?
      end
    end

    context 'when I pass an invalid resource, subnet, az, or vpc_id' do
      xit 'do something'
    end
  end

  describe 'get_termination_protection' do
    context 'when I pass a valid client, instance_id and the instance is protected from termination' do
      let (:termination_protection) { Vominator::EC2.get_termination_protection(@ec2_client, 'i-1968d168')}

      subject { termination_protection }

      it 'should be protected from termination' do
        @ec2_client.stub_responses(:describe_instance_attribute, :instance_id => 'i-1968d168', :disable_api_termination => { :value => true })
        expect { termination_protection}.to_not raise_error
        expect(termination_protection).to be true
      end
    end

    context 'when I pass a valid client, instance_id, and the instance is not protected from termination' do
      let (:termination_protection) { Vominator::EC2.get_termination_protection(@ec2_client, 'i-1766874c')}

      subject { termination_protection }

      it 'should not be protected from termination' do
        @ec2_client.stub_responses(:describe_instance_attribute, :instance_id => 'i-1766874c', :disable_api_termination => { :value => false })
        expect { termination_protection}.to_not raise_error
        expect(termination_protection).to be false
      end
    end

    context 'when I pass an invalid client, or instance_id' do
      xit 'do something'
    end
  end

  describe 'set_termination_protection' do
    context 'When I pass a valid client, instance_id and set the instance protection to true' do
      let (:termination_protection) { Vominator::EC2.set_termination_protection(@ec2_client, 'i-1968d168', true)}

      subject { termination_protection }

      it 'should be enabled' do
        @ec2_client.stub_responses(:describe_instance_attribute, :instance_id => 'i-1968d168', :disable_api_termination => { :value => true })
        expect { termination_protection }.to_not raise_error
        expect(termination_protection).to be true
      end
    end

    context 'When I pass a valid client, instance_id and set the instance protection to false' do
      let (:termination_protection) { Vominator::EC2.set_termination_protection(@ec2_client, 'i-1968d168', false)}

      subject { termination_protection }

      it 'should not be enabled' do
        @ec2_client.stub_responses(:describe_instance_attribute, :instance_id => 'i-1968d168', :disable_api_termination => { :value => false })
        expect { termination_protection }.to_not raise_error
        expect(termination_protection).to be false
      end
    end

    context 'when I pass an invalid client, instance_id or state' do
      xit 'do something'
    end
  end
end
