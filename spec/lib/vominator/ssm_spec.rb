require 'spec_helper'
require 'vominator/ssm'

describe Vominator::SSM do
  before(:each) do
    Aws.config[:stub_responses] = true
    @ssm = Aws::SSM::Client.new
  end

  describe 'get_documents' do
    context 'when I pass a valid client' do
      let (:documents) { Vominator::SSM.get_documents(@ssm,2)}

      subject { documents }

      it 'returns an array of document names' do
        @ssm.stub_responses(:list_documents, {:next_token => 'abcd', :document_identifiers => [{:name => 'document1'},{:name => 'document2'}]},
                            {:next_token => nil, :document_identifiers => [{:name => 'document3'},{:name => 'document4'}]})

        expect {documents}.to_not raise_error
        expect(documents.count).to eq 4
        expect(documents).to include('document3')
      end
    end
  end

  describe 'describe_document' do
    context 'when I pass a valid client and name' do
      let (:document) { Vominator::SSM.describe_document(@ssm,'document-3')}

      subject { document }

      it 'returns details about a document' do
        @ssm.stub_responses(:describe_document, :document => {:created_date => Time.now, :name => 'document-3', :status => 'active', :sha_1 => 'abcd'})
        expect { document}.to_not raise_error
        expect(document.name).to match 'document-3'
      end
    end
  end

  describe 'get_document' do
    context 'when I pass a valid client and name' do
      let (:document) { Vominator::SSM.get_document(@ssm, 'document-3')}

      subject { document }

      it 'returns the document' do
        @ssm.stub_responses(:get_document, {:content => '{"schemaVersion":"1.0","description":"test policy"}', :name => 'document-3'})
        expect { document }.to_not raise_error
        expect(document.name).to match 'document-3'
        expect(document.content).to match '{"schemaVersion":"1.0","description":"test policy"}'
      end
    end
  end
  describe 'put_document' do
    context 'when I pass a valid client, name, and data' do
      let (:document) { Vominator::SSM.put_document(@ssm, 'document-5','{"schemaVersion":"1.0","description":"test policy"}') }

      subject { document }

      it 'creates the document' do
        @ssm.stub_responses(:describe_document, :document => {:created_date => Time.now, :name => 'document-5', :status => 'active', :sha_1 => 'abcd'})
        expect { document }.to_not raise_error
      end
    end
  end

  describe 'associated' do
    context 'when I pass a valid client, name and instance_id and is associated to the instance' do
      let (:association) { Vominator::SSM.associated?(@ssm, 'document-1','i-123456')}

      subject { association }

      it 'returns true' do
        @ssm.stub_responses(:describe_association, :association_description => {:date => Time.now, :instance_id => 'i-123456', :name => 'document-1', :status => {:name => 'Success', :date => Time.now, :message => 'It worked'}})
        expect { association }.to_not raise_error
        expect(association).to be true
      end
    end
  end

  describe 'create_association' do
    context 'when I pass a valid client, name, and instance_id' do
      let (:association) { Vominator::SSM.create_association(@ssm, 'document-1','i-123456')}

      subject { association }

      it 'returns true' do
        @ssm.stub_responses(:describe_association, :association_description => {:date => Time.now, :instance_id => 'i-123456', :name => 'document-1', :status => {:name => 'Success', :date => Time.now, :message => 'It worked'}})
        expect { association }.to_not raise_error
        expect(association).to be true
      end
    end
  end
end