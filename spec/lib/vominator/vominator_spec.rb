require 'spec_helper'
require 'vominator/vominator'

describe Vominator do

  describe 'get_config' do
    context 'when I pass an invalid config file' do
      let(:vominator_config) { Vominator.get_config('/badpath') }

      subject { vominator_config }

      it 'should equal false' do
        cached_vominator_config = ENV.delete('VOMINATOR_CONFIG')
        expect(subject).to be false
        ENV['VOMINATOR_CONFIG'] = cached_vominator_config
      end

    end

    context 'when I pass a valid config file' do
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

    context 'when I pass an invalid directory' do
      let (:puke_config) { Vominator.get_puke_config('/badpath')}

      subject { puke_config }

      it 'should raise an error' do
        expect { puke_config }.to raise_error
      end
    end

    context 'when I pass a valid directory' do
      let (:puke_config) { Vominator.get_puke_config(VOMINATOR_CONFIG['configuration_path'])}

      subject { puke_config }

      it 'should not raise an error' do
        expect { puke_config }.to_not raise_error
      end
    end
  end

  describe 'get_key_pair' do
    context 'when I pass a valid Vominator config' do
      vominator_config = Vominator.get_config('test/vominator.yaml')
      let (:key_pair) { Vominator.get_key_pair(vominator_config) }

      subject { key_pair }

      it 'should return a key_pair name' do
        expect { key_pair }.to_not raise_error
        expect(key_pair).to match 'ci@example.com'
      end
    end
  end
  describe 'get_puke_variables' do

    context 'when I pass an invalid environment' do
      let (:puke_variables) { Vominator.get_puke_variables('invalid_environment')}

      subject { puke_variables }

      xit 'should raise an error' do
        expect { puke_variables }.to raise_error
      end
    end

    context 'when I pass a valid environment' do
      let (:puke_variables) { Vominator.get_puke_variables('test')}

      subject { puke_variables }

      it 'should not raise an error' do
        expect { puke_variables }.to_not raise_error
      end
    end
  end

  describe 'yesno' do
    context 'default is yes' do
      let (:yesno) { Vominator.yesno? }
      context 'when I say yes' do
        it 'should prompt the user and return true' do
          expect($terminal).to receive(:ask).with('Continue? [Y/n] ').and_return('y')
          expect(yesno).to be_truthy
        end
      end

      context 'when I say no' do
        it 'should prompt the user and return false' do
          expect($terminal).to receive(:ask).with('Continue? [Y/n] ').and_return('n')
          expect(yesno).to be_falsey
        end
      end
    end

    context 'default is no' do
      let (:yesno) { Vominator.yesno?(default: false) }
      context 'when I say yes' do
        it 'should prompt the user and return true' do
          expect($terminal).to receive(:ask).with('Continue? [y/N] ').and_return('y')
          expect(yesno).to be_truthy
        end
      end

      context 'when I say no' do
        it 'should prompt the user and return false' do
          expect($terminal).to receive(:ask).with('Continue? [y/N] ').and_return('n')
          expect(yesno).to be_falsey
        end
      end
    end
  end
end

describe Vominator::Logger do
  describe 'info' do
    context 'when I pass a log message' do
      message = 'This is a test message'
      let (:info_log) { Vominator::Logger.info(message) }

      subject { info_log }

      it 'should print the log message' do
        expect { info_log }.to output("#{message}\n").to_stdout
      end
    end
  end

  describe 'test' do
    context 'when I pass a log message' do
      message = 'This is a test message'
      let (:test_log) { Vominator::Logger.test(message) }

      subject { test_log }

      it 'should print the log message' do
        expect { test_log }.to output("\e[36m#{message}\e[0m\n").to_stdout
      end
    end
  end

  describe 'error' do
    context 'when I pass a log message' do
      message = 'This is a test message'
      let (:error_log) { Vominator::Logger.error(message) }

      subject { error_log }

      it 'should print the log message' do
        expect { error_log }.to output("\e[31m#{message}\e[0m\n").to_stdout
      end
    end
  end

  describe 'fatal' do
    context 'when I pass a log message' do
      message = 'This is a test message'
      let (:fatal_log) { Vominator::Logger.fatal(message) }

      subject { fatal_log }

      it 'should print the log message and exit' do
        expect { fatal_log }.to exit_with_code(1).and output("\e[31m#{message}\e[0m\n").to_stdout 
      end
    end
  end

  describe 'success' do
    context 'when I pass a log message' do
      message = 'This is a test message'
      let (:success_log) { Vominator::Logger.success(message) }

      subject { success_log }

      it 'should print the log message' do
        expect { success_log }.to output("\e[32m#{message}\e[0m\n").to_stdout
      end
    end
  end

  describe 'warning' do
    context 'when I pass a log message' do
      message = 'This is a test message'
      let (:warning_log) { Vominator::Logger.warning(message) }

      subject { warning_log }

      it 'should print the log message' do
        expect { warning_log }.to output("\e[33m#{message}\e[0m\n").to_stdout
      end
    end
  end
end
