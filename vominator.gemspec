# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'vominator/version'

Gem::Specification.new do |spec|
  spec.name          = "vominator"
  spec.version       = Vominator::VERSION
  spec.authors       = ["Chris Kelly", "Kevin Loukinen", "Chris McNabb"]
  spec.email         = ["ckelly@newsinc.com", "kloukinen@newsinc.com", "cmcnabb@newsinc.com"]
  spec.summary       = %q{Manage AWS resources from JSON templates and CLI.}
  spec.description   = %q{Leverage the power of CLI with your favorite revision control system to create and manage AWS infrastructure.}
  spec.homepage      = ""
  spec.license       = "gplv3"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = %w{vominate}
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "aws-sdk", "~> 2.0"
  spec.add_dependency "colored", "~> 1.2"
  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
end
