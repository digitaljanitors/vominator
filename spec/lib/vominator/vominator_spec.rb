require 'spec_helper'
require 'vominator/vominator'

describe Vominator do
  before(:all) do
    VOMINATOR_CONFIG = Vominator.get_config
    PUKE_CONFIG = Vominator.get_puke_config(VOMINATOR_CONFIG['configuration_path'])
  end

  describe 'get_config' do
    context 'When I pass an invalid config file' do
      let(:vominator_config) { Vominator.get_config('/badpath') }

      subject { vominator_config }

      it 'should equal false' do
        cached_vominator_config = ENV.delete('VOMINATOR_CONFIG')
        expect(subject).to be false
        ENV['VOMINATOR_CONFIG'] = cached_vominator_config
      end

    end

    context 'When I pass a valid config file' do
      let(:vominator_config) { Vominator.get_config('test/vominator.yaml') }

      subject { vominator_config }

      it { is_expected.not_to be false }
      it { is_expected.to include('access_key_id' => 'DUMMY_ACCESS_KEY') }
      it { is_expected.to include('secret_access_key' => 'DUMMY_SECRET_KEY') }
      it { is_expected.to include('configuration_path' => 'test/puke') }
      it { is_expected.to include('key_pair_name' => 'ci@example.com') }
      it { is_expected.to include('chef_client_key' => 'ci.pem') }
      it { is_expected.to include('chef_client_name' => 'ci') }
    end
  end

  describe 'get_puke_config' do

    context 'When I pass an invalid directory' do
      let (:puke_config) { Vominator.get_puke_config('/badpath')}

      subject { puke_config }

      it 'should raise an error' do
        expect { puke_config }.to raise_error
      end
    end

    context 'When I pass a valid directory' do
      let (:puke_config) { Vominator.get_puke_config(VOMINATOR_CONFIG['configuration_path'])}

      subject { puke_config }

      it 'should not raise an error' do
        expect { puke_config }.to_not raise_error
      end
    end
  end

  describe 'get_puke_variables' do

    context 'When I pass an invalid environment' do
      let (:puke_variables) { Vominator.get_puke_variables('invalid_environment')}

      subject { puke_variables }

      xit 'should raise an error' do
        expect { puke_variables }.to raise_error
      end
    end

    context 'When I pass a valid environment' do
      let (:puke_variables) { Vominator.get_puke_variables('test')}

      subject { puke_variables }

      it 'should not raise an error' do
        expect { puke_variables }.to_not raise_error
      end
    end
  end
end
