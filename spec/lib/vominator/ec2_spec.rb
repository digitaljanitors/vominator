require 'spec_helper'
require 'vominator/ec2'
require 'pry'

describe Vominator::EC2 do

  before(:all) do
    @puke_variables = Vominator.get_puke_variables('test')
    Aws.config[:stub_responses] = true
    @ec2_client = Aws::EC2::Client.new
    @ec2_client.stub_responses(:describe_instances, :next_token => nil, :reservations => [
      {
        :reservation_id => 'r-567b402e',
        :owner_id => '012329383471727',
        :groups => [],
        :instances => [{
          :instance_id => 'i-1968d168',
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

  describe 'get_security_groups' do
    context 'when I pass a valid resource and vpc_id' do

    end

    context 'when I pass an invalid resource or vpc_id' do
      xit 'do something'
    end
  end

  describe 'get_subnets' do
    context 'when I pass a valid resource and vpc_id' do

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

    end

    context 'when I pass an invalid resource, subnet, az, or vpc_id' do
      xit 'do something'
    end
  end
end
