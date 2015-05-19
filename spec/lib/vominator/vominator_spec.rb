require 'spec_helper'
require 'vominator/vominator'

describe Vominator do
  describe 'get_config' do

    context 'When I pass an invalid config file' do
      let(:vominator_config) { Vominator.get_config('/badpath') }

      subject { vominator_config }

      it { is_expected.to be false}
    end

    context 'When I pass a valid config file' do
      let(:vominator_config) { Vominator.get_config('test/vominator.yaml') }

      subject { vominator_config }

      it { is_expected.not_to be false }
      it { is_expected.to include('access_key_id' => 'DUMMY_ACCESS_KEY') }
      it { is_expected.to include('secret_access_key' => 'DUMMY_SECRET_KEY') }
    end
  end
end
