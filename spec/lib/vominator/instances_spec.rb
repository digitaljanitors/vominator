require 'spec_helper'
require 'vominator/instances'

describe Vominator::Instances do
  describe 'get_instances' do
    context 'when I pass a valid environment and product' do
      let (:instances) {Vominator::Instances.get_instances('test', 'sample-api')}

      subject { instances }

      it 'should not raise an error' do
        expect { instances }.to_not raise_error
      end

      it 'should contain 3 sample api instances' do
        # noinspection RubyResolve
        expect(instances).to contain_exactly({'sample-api-1' => nil,
                                      'type' => {
                                          'prod' => 'm3.medium',
                                          'staging' => 'm3.medium'},
                                     'ami'=>'ami-123123',
                                     'os'=>'linux',
                                     'ip'=>'10.OCTET.41.21',
                                     'az'=>'us-east-1c',
                                     'environment'=>['staging'],
                                     'security_groups'=>['sample-api-server'],
                                     'chef_recipes'=>['srv_sample_api']
                                     },
                                     {'sample-api-2' => nil,
                                      'type' => {
                                          'prod' => 'm3.medium',
                                          'staging' => 'm3.medium'},
                                      'os'=>'linux',
                                      'ip'=>'10.OCTET.42.21',
                                      'az'=>'us-east-1d',
                                      'security_groups'=>['sample-api-server'],
                                      'chef_recipes'=>['srv_sample_api']
                                     },
                                     {'sample-api-3' => nil,
                                      'type' => {
                                          'prod' => 'm3.medium',
                                          'staging' => 'm3.medium'},
                                      'os'=>'linux',
                                      'ip'=>'10.OCTET.43.21',
                                      'az'=>'us-east-1e',
                                      'security_groups'=>['sample-api-server'],
                                      'chef_recipes'=>['srv_sample_api']
                                     })
      end
    end

    context 'when I pass a filter' do
      let (:instances) {Vominator::Instances.get_instances('test', 'sample-api', ['sample-api-1'])}

      subject { instances }

      it 'it should filter the results' do
        expect(instances).to contain_exactly({'sample-api-1' => nil,
                                              'type' => {
                                                  'prod' => 'm3.medium',
                                                  'staging' => 'm3.medium'},
                                              'ami'=>'ami-123123',
                                              'os'=>'linux',
                                              'ip'=>'10.OCTET.41.21',
                                              'az'=>'us-east-1c',
                                              'environment'=>['staging'],
                                              'security_groups'=>['sample-api-server'],
                                              'chef_recipes'=>['srv_sample_api']
                                             })

      end
    end
    context 'when I pass an invalid environment or product' do
      xit 'it should do something'
    end

  end
end