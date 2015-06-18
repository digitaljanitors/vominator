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


  end
end
