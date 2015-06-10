require 'spec_helper'
require 'vominator/ec2'
require 'pry'
describe Vominator::EC2 do

  before(:each) do
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
          :state => { :code => 16, :name => 'running'},
          :tags => [{:key => 'Name', :value => 'sample-api-1.test'}],
          :placement => {:availability_zone => 'us-east-1c'},
          :security_groups => [{:group_name => 'test-sample-api-server', :group_id => 'sg-11111'}],
          :block_device_mappings => [{:device_name => 'sdf', :ebs => {:volume_id => 'vol-11111', :status => 'in-use'}}]
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
           :state => { :code => 16, :name => 'running'},
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
           :state => { :code => 16, :name => 'running'},
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
    @ec2_client.stub_responses(:describe_volumes, :next_token => nil, :volumes => [
     :volume_id => 'vol-11111',
     :size => 100,
     :availability_zone => 'us-east-1c',
     :state => 'in-use',
     :attachments => [{
                          :volume_id => 'vol-11111',
                          :instance_id => 'i-1968d168',
                          :device => 'sdf',
                          :state => 'in-use'
                      }]
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
        expect(instances['10.203.41.21'][:instance_id]).to match 'i-1968d168'
        expect(instances['10.203.41.21'][:security_groups].first).to include('test-sample-api-server')
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
  describe 'get_instance_state' do
    context 'when I pass a valid resource and instance_id' do
      let (:instance_state) { Vominator::EC2.get_instance_state(@ec2, 'i-1968d168') }

      subject { instance_state }

      it 'should return running when the instance is running' do
        @ec2_client.stub_responses(:describe_instances, :next_token => nil, :reservations => [
          {
              :reservation_id => 'r-567b402e',
              :instances => [{
                                 :instance_id => 'i-1968d168',
                                 :instance_type => 'm3.large',
                                 :state => { :code => 64, :name => 'running'},
                             }]
          }])

        expect { instance_state }.to_not raise_error
        expect(instance_state).to match 'running'
      end

      it 'should return stopped when the instance is stopped' do
        @ec2_client.stub_responses(:describe_instances, :next_token => nil, :reservations => [
          {
              :reservation_id => 'r-567b402e',
              :instances => [{
                                 :instance_id => 'i-1968d168',
                                 :instance_type => 'm3.large',
                                 :state => { :code => 64, :name => 'stopped'},
                             }]
          }])

        expect { instance_state }.to_not raise_error
        expect(instance_state).to match 'stopped'
      end
    end
  end

  describe 'set_instance_type' do
    context 'when I pass a valid resource, instance_id, and instance_type' do
      let (:instance_type) { Vominator::EC2.set_instance_type(@ec2, 'i-1968d168', 'm3.large', 'sample-api-1.test.example.com')}

      subject { instance_type }

      it 'should resize the instance' do
        @ec2_client.stub_responses(:describe_instances, :next_token => nil, :reservations => [
          {
              :reservation_id => 'r-567b402e',
              :instances => [{
                                 :instance_id => 'i-1968d168',
                                 :instance_type => 'm3.large',
                                 :state => { :code => 64, :name => 'stopped'},
                             }]
          }])
        expect { instance_type }.to_not raise_error
        expect(instance_type).to match 'm3.large'
      end
    end

    context 'when I pass an invalid resource, instance_id, or instance_type' do
      xit 'do something'
    end
  end

  describe 'assign_public_ip' do
    context 'when I pass a valid resource and instance_id' do
      let (:public_ip) { Vominator::EC2.assign_public_ip(@ec2_client, 'i-1968d168' )}

      subject { public_ip }

      it 'should assign the instance an public ip' do
        @ec2_client.stub_responses(:allocate_address, :public_ip => '84.84.84.84')
        expect { public_ip }.to_not raise_error
        expect(public_ip).to match '84.84.84.84'
      end
    end

    context 'when i pass an invalid resource and instance_id' do
      xit 'do something'
    end
  end

  describe 'remove_public_ip' do
    context 'when I pass a valid resource and instance_id' do
      let (:removed_public_ip) { Vominator::EC2.remove_public_ip(@ec2_client, 'i-1968d168' )}

      subject { removed_public_ip }

      it 'should remove the instance an public ip' do
        @ec2_client.stub_responses(:describe_addresses, :addresses => [{:instance_id => 'i-1968d168', :public_ip => '84.84.84.84'}])
        expect { removed_public_ip }.to_not raise_error
        expect(removed_public_ip).to be true
      end
    end

    context 'when i pass an invalid resource and instance_id' do
      xit 'do something'
    end
  end

  describe 'set_source_dest_check' do
    context 'when I pass a valid resource, instance_id and enable source destination checking' do
      let (:source_dest_check) { Vominator::EC2.set_source_dest_check(@ec2, 'i-1968d168', true )}

      subject { source_dest_check }

      it 'should remove the instance an public ip' do
        @ec2_client.stub_responses(:describe_instances, :next_token => nil, :reservations => [
                                                          {
                                                              :reservation_id => 'r-567b402e',
                                                              :instances => [{
                                                                                 :instance_id => 'i-1968d168',
                                                                                 :instance_type => 'm3.large',
                                                                                 :source_dest_check => true
                                                                             }]
                                                          }])

        expect { source_dest_check }.to_not raise_error
        expect(source_dest_check).to be true
      end
    end

    context 'when I pass a valid resource, instance_id and disabling source destination checking' do
      let (:source_dest_check) { Vominator::EC2.set_source_dest_check(@ec2, 'i-1968d168', false )}

      subject { source_dest_check }

      it 'should remove the instance an public ip' do
        @ec2_client.stub_responses(:describe_instances, :next_token => nil, :reservations => [
                                                          {
                                                              :reservation_id => 'r-567b402e',
                                                              :instances => [{
                                                                                 :instance_id => 'i-1968d168',
                                                                                 :instance_type => 'm3.large',
                                                                                 :source_dest_check => false
                                                                             }]
                                                          }])
        expect { source_dest_check }.to_not raise_error
        expect(source_dest_check).to be false
      end
    end

    context 'when i pass an invalid resource, instance_id, or state' do
      xit 'do something'
    end
  end

  describe 'set_ebs_optimized' do
    context 'when I pass a valid resource, instance_id and enable EBS optimization' do
      let (:ebs_optimized) { Vominator::EC2.set_ebs_optimized(@ec2, 'i-1968d168', true, 'sample-api-1.example.com' )}

      subject { ebs_optimized }

      it 'should remove the instance an public ip' do
        @ec2_client.stub_responses(:describe_instances, :next_token => nil, :reservations => [
                                                          {
                                                              :reservation_id => 'r-567b402e',
                                                              :instances => [{
                                                                                 :instance_id => 'i-1968d168',
                                                                                 :instance_type => 'm3.large',
                                                                                 :ebs_optimized => true,
                                                                                 :state => { :code => 64, :name => 'stopped'}
                                                                             }]
                                                          }])
        expect { ebs_optimized }.to_not raise_error
        expect(ebs_optimized).to be true
      end
    end

    context 'when I pass a valid resource, instance_id and disabling EBS optimization' do
      let (:ebs_optimized) { Vominator::EC2.set_ebs_optimized(@ec2, 'i-1968d168', false, 'sample-api-1.example.com' )}

      subject { ebs_optimized }

      it 'should remove the instance an public ip' do
        @ec2_client.stub_responses(:describe_instances, :next_token => nil, :reservations => [
                                                          {
                                                              :reservation_id => 'r-567b402e',
                                                              :instances => [{
                                                                                 :instance_id => 'i-1968d168',
                                                                                 :instance_type => 'm3.large',
                                                                                 :ebs_optimized => false,
                                                                                 :state => { :code => 64, :name => 'stopped'}
                                                                             }]
                                                          }])
        expect { ebs_optimized }.to_not raise_error
        expect(ebs_optimized).to be false
      end
    end

    context 'when i pass an invalid resource, instance_id, or state' do
      xit 'do something'
    end
  end

  describe 'set_security_groups' do
    context 'when I pass a valid resource, instance_id, security_groups, and vpc_security_groups' do
      vpc_security_groups = Hash.new
      vpc_security_groups['test-sample-api-server'] = 'sg-11111'
      let (:security_groups) { Vominator::EC2.set_security_groups(@ec2, 'i-1968d168', ['test-security-group'], vpc_security_groups)}

      subject { security_groups }

      it 'should append test-security-group to the instances list of security groups' do
        @ec2_client.stub_responses(:describe_instances, :next_token => nil, :reservations => [
                                                          {
                                                              :reservation_id => 'r-567b402e',
                                                              :instances => [{
                                                                                 :instance_id => 'i-1968d168',
                                                                                 :security_groups => [{ :group_name => 'test-sample-api-server', :group_id => 'sg-11111'}, { :group_name => 'test-security-group', :group_id => 'sg-11113'}]
                                                                             }]
                                                          }])
        expect { security_groups }.to_not raise_error
        expect(security_groups.count).to eq 2
        expect(security_groups).to include 'test-sample-api-server'
        expect(security_groups).to include 'test-security-group'
      end
    end

    context 'when I pass a valid resource, instance_id, security_groups, vpc_security_groups, and set append to false' do
      vpc_security_groups = Hash.new
      vpc_security_groups['test-sample-api-server'] = 'sg-11111'
      let (:security_groups) { Vominator::EC2.set_security_groups(@ec2, 'i-1968d168', ['test-security-group'], vpc_security_groups, false)}

      subject { security_groups }

      it 'should append test-security-group to the instances list of security groups' do
        @ec2_client.stub_responses(:describe_instances, :next_token => nil, :reservations => [
                                                          {
                                                              :reservation_id => 'r-567b402e',
                                                              :instances => [{
                                                                                 :instance_id => 'i-1968d168',
                                                                                 :security_groups => [{ :group_name => 'test-security-group', :group_id => 'sg-11113'}]
                                                                             }]
                                                          }])
        expect { security_groups }.to_not raise_error
        expect(security_groups.count).to eq 1
        expect(security_groups).to include 'test-security-group'
      end
    end
  end

  describe 'get_ebs_volume' do
    context 'when I pass a valid resource and ebs_volume_id' do
      let (:volume) { Vominator::EC2.get_ebs_volume(@ec2, 'vol-11111') }

      subject { volume }

      it 'should return a valid aws ec2 volume object' do
        expect { volume }.to_not raise_error
        expect(volume.id).to eq 'vol-11111'
      end
    end

    context 'when I pass an invalid resource or ebs_volume_id' do
      xit 'do something'
    end

  end

  describe 'get_instance_ebs_volumes' do
    context 'when I pass a valid resource and instance id' do
      let (:volumes) { Vominator::EC2.get_instance_ebs_volumes(@ec2, 'i-1968d168') }

      subject { volumes }

      it 'should return a list of device names for attached ebs volumes' do
        expect { volumes }.to_not raise_error
        expect(volumes.count).to eq 1
        expect(volumes.first).to match 'sdf'
      end
    end

    context 'when I pass an invalid resource or instance id' do
      xit 'do something'
    end
  end

  describe 'add_ebs_volume' do
    context 'when I pass a valid resource, instance_id, volume_type, volume_size, and mount_point)' do
      let (:volume) { Vominator::EC2.add_ebs_volume(@ec2, 'i-1968d168', 'magnetic', 100, 'sdf')}

      subject { volume }

      it 'should return a valid volume object' do
        @ec2_client.stub_responses(:describe_volumes,
                                   {:volumes => [{:volume_id => 'vol-11111', :size => 100, :availability_zone => 'us-east-1c', :state => 'available'}]},
                                   {:volumes => [{:volume_id => 'vol-11111', :size => 100, :availability_zone => 'us-east-1c', :state => 'in-use'}]}
        )
        @ec2_client.stub_responses(:create_volume, :volume_id => 'vol-11111', :size => 100, :availability_zone => 'us-east-1c', :state => 'in-use', :attachments => [{:device => 'sdf', :volume_id => 'vol-11111', :state => 'in-use'}])
        expect { volume }.to_not raise_error
        expect(volume.attachments.first.device).to match 'sdf'
      end
    end
  end

  describe 'get_ephemeral_devices' do
    context 'when I pass a valid instance type' do
      let (:devices) { Vominator::EC2.get_ephemeral_devices('m3.medium') }

      subject { devices }

      it 'should return a hash consisting of mount points and ephemeral device ids' do
        expect {devices}.to_not raise_error
        expect(devices.count).to eq 1
        expect(devices['/dev/sdb']).to match 'ephemeral0'
      end
    end

    context 'when I pass an invalid instance type' do
      xit 'do something'
    end
  end
end
