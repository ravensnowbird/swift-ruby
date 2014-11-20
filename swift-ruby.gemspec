# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'swift_storage/version'

Gem::Specification.new do |spec|
  spec.name          = "swift-storage"
  spec.version       = SwiftStorage::VERSION
  spec.authors       = ["Nicolas Goy"]
  spec.email         = ["kuon@goyman.com"]
  spec.summary       = %q{TODO: Write a short summary. Required.}
  spec.description   = %q{TODO: Write a longer description. Optional.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]


  spec.add_dependency "oj", "~> 2.11.1"

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.1.0"
  spec.add_development_dependency "guard", "~> 2.8.2"
  spec.add_development_dependency "guard-rspec", "~> 4.3.1"
  spec.add_development_dependency "rack", "~> 1.5.2"
  spec.add_development_dependency "yard", "~> 0.8.7.6"
  spec.add_development_dependency "redcarpet", "~> 0.8.7.6"
end
