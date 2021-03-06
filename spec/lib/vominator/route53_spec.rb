require 'spec_helper'
require 'vominator/route53'

describe Vominator::Route53 do
  before(:all) do
    @puke_variables = Vominator.get_puke_variables('test')
    Aws.config[:stub_responses] = true
    @r53 = Aws::Route53::Client.new
    @r53.stub_responses(:list_resource_record_sets, { :is_truncated => false, :max_items => 50, :resource_record_sets => [
                                                      { :name => 'sample-api-1.test.example.com.', :type => 'A', :resource_records => [{ :value => '10.203.41.21'}] },
                                                      { :name => 'sample-api-2.test.example.com.', :type => 'A', :resource_records => [{ :value => '10.203.42.21'}] },
                                                      { :name => 'sample-api-3.test.example.com.', :type => 'A', :resource_records => [{ :value => '10.203.43.21'}] }
                                                  ]}
    )
  end

  describe 'get_records' do
    context 'when I pass a valid route53 client and an invalid zone file' do
      xit 'should do something'
    end

    context 'when I pass an invalid route53 client and a valid zone file' do
      xit 'should do something'
    end

    context 'when I pass an invalid route53 client and an invalid zone file' do
      xit 'should do something'
    end

    context 'when I pass a valid route53 client and zone file' do
      let(:records) { Vominator::Route53.get_records(@r53,"/hostedzone/#{@puke_variables['zone']}", 2)}

      subject { records }

      it { is_expected.to include('sample-api-1.test.example.com.') }
      it { is_expected.to include('sample-api-2.test.example.com.') }
      it { is_expected.to include('sample-api-3.test.example.com.') }
    end
  end

  describe 'create_record' do
    context 'when I pass a valid route53 client, zone, fqdn, and ip' do
      let (:response) { Vominator::Route53.create_record(@r53,"#{@puke_variables['zone']}", 'sample-api-1.test.example.com', '10.203.41.21')}

      subject { response }

      it 'should return true' do
        @r53.stub_responses(:change_resource_record_sets, :change_info => { :status => 'PENDING', :id => '12345', :submitted_at => Time.now})
      end
    end
  end

  describe 'delete_record' do
    context 'When I pass a valid route53 client, zone, fqdn, and ip' do
      let (:response) { Vominator::Route53.delete_record(@r53, "#{@puke_variables['zone']}",'sample-api-1.test.example.com', '10.203.41.21')}

      subject { response }

      it 'should return true' do
        @r53.stub_responses(:change_resource_record_sets, :change_info => { :status => 'PENDING', :id => '12345', :submitted_at => Time.now})
      end
    end
  end
end