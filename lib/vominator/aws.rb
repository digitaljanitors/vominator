require 'aws-sdk'
require_relative 'vominator'

Aws.config[:credentials] = Aws::Credentials.new(VOMINATOR_CONFIG['access_key_id'], VOMINATOR_CONFIG['secret_access_key'])

module Vominator
  class AWS

  end
end
