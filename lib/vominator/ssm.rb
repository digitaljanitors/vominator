require_relative 'constants'

module Vominator
  class SSM

    def self.get_documents(client,max_results=25)
        resp = client.list_documents(:max_results => max_results)
        documents = resp[:document_identifiers]
        while resp[:next_token]
          resp = client.list_documents(:next_token => resp[:next_token])
          documents += resp[:document_identifiers]
        end

        return documents.map {|doc| doc.name }
    end

    def self.describe_document(client,name)
        return client.describe_document(:name => name).document
    end

    def self.get_document(client,name)
      return client.get_document(:name => name)
    end

    def self.put_document(client,name,data)
      client.create_document(:name => name, :content => data)
      sleep 2 until Vominator::SSM.describe_document(client,name).status == 'active'

      if Vominator::SSM.describe_document(client,name).status == 'active'
        return true
      else
        return false
      end
    end

    def self.associated?(client,name,instance_id)
      begin
        client.describe_association(:name => name, :instance_id => instance_id)
        return true
      rescue Aws::SSM::Errors::AssociationDoesNotExist
        return false
      end
    end

    def self.create_association(client,name,instance_id)
      client.create_association(:name => name, :instance_id => instance_id)
      sleep 2 until Vominator::SSM.associated?(client,name,instance_id)

      if Vominator::SSM.associated?(client,name,instance_id)
        return true
      else
        return false
      end
    end
  end
end
