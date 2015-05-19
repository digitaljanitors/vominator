require 'spec_helper'
require 'vominator/route53'

describe Vominator::Route53 do
  before(:all) do
    @puke_variables = Vominator.get_puke_variables('test')
    @r53 = Aws::Route53::Client.new(stub_responses: true)
    @r53.stub_responses(:list_resource_record_sets, resource_record_sets:[
                                                      { name:'sample-api-1.test.example.com.', resource_records:[{ value: '10.203.41.21'}] },
                                                      { name:'sample-api-2.test.example.com.', resource_records:[{ value: '10.203.42.21'}] },
                                                      { name:'sample-api-3.test.example.com.', resource_records:[{ value: '10.203.43.21'}] }
                                                  ],
                                                  is_truncated: true,
                                                  is_truncated: false
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
      let(:records) { Vominator::Route53.get_records(@r53,"/hostedzone/#{@puke_variables['zone']}")}

      subject { records }

      it { is_expected.to include('sample-api-1.test.example.com.') }
      it { is_expected.to include('sample-api-2.test.example.com.') }
      it { is_expected.to include('sample-api-3.test.example.com.') }
    end
  end
end