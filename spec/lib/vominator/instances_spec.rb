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
                                     'family'=>'linux',
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
                                      'family'=>'linux',
                                      'ip'=>'10.OCTET.42.21',
                                      'az'=>'us-east-1d',
                                      'security_groups'=>['sample-api-server'],
                                      'chef_recipes'=>['srv_sample_api']
                                     },
                                     {'sample-api-3' => nil,
                                      'type' => {
                                          'prod' => 'm3.medium',
                                          'staging' => 'm3.medium'},
                                      'family'=>'linux',
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
                                              'family'=>'linux',
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

  describe 'generate_cloud_config' do
    context 'when I pass a valid hostname, environment, family, roles, and recipes' do
      let (:cloud_config) { Vominator::Instances.generate_cloud_config('sample-api-1', 'test', 'test', 'linux', ['role1'], ['recipe1'] )}

      subject { cloud_config }
      it 'should return a rendered cloud_config' do
        expect {cloud_config}.to_not raise_error
        expect(cloud_config).to include('sample-api-1.test')
        expect(cloud_config).to include('role1')
        expect(cloud_config).to include('recipe1')
      end
    end

    context 'when I pass invalid parameters' do
      xit 'it should do something'
    end
  end
end
