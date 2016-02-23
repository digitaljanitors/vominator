require 'spec_helper'
require 'vominator/ec2info'
require 'pry'

describe Vominator::EC2Info, fakefs: true do
  describe 'EC2Info' do
    cwd = Dir.pwd()
    before(:each) { FakeFS::FileSystem.clone(cwd, '/') }

    let (:file) { 'test/instances.json' }
    let (:ec2info) { Vominator::EC2Info::InstanceInfo.new }
    context 'when I do not pass a file to new' do
      it 'creates the file from the http request' do
        expect { ec2info }.to_not raise_error
        expect(File.exist?(file)).to be
      end
    end

    context 'when I pass a file to new' do
      let (:file) { 'test/myinstances.json' }
      let (:ec2info) { Vominator::EC2Info::InstanceInfo.new(file) }
      it 'creates the file from the http request' do
        expect { ec2info }.to_not raise_error
        expect(File.exist?(file)).to be
      end
    end

    context 'when I get an instance type' do
      let(:itype) { ec2info.get_instance_type('t2.nano') }
      it 'returns the instance info' do
        expect { itype }.to_not raise_error
        expect(itype).to be_a(Vominator::EC2Info::InstanceType)
        expect(itype.instance_type).to eq('t2.nano')
        expect(itype.memory).to eq(0.5)
        expect(itype.ephemeral_devices).to eq(0)
      end
    end
  end

  
    

end
