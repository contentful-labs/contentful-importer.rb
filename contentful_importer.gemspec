# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require File.expand_path('../lib/contentful/importer/version', __FILE__)

Gem::Specification.new do |spec|
  spec.name          = 'contentful-importer'
  spec.version       = Contentful::Importer::VERSION
  spec.authors       = ['Contentful GmbH (Andreas Tiefenthaler)']
  spec.email         = ['rubygems@contentful.com']
  spec.description   = 'Generic importer for contentful.com'
  spec.summary       = 'Allows to import structured data to contentful.com'
  spec.homepage      = 'https://github.com/contentful/contentful-importer.rb'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables    << 'contentful-importer'
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'http', '~> 0.9'
  spec.add_dependency 'multi_json', '~> 1'
  spec.add_dependency 'contentful-management', '~> 0.7.0'
  spec.add_dependency 'activesupport','~> 4.1'
  spec.add_dependency 'claide','~> 0.8.1'
  spec.add_dependency 'api_cache', ' ~> 0.3.0'
  spec.add_dependency 'i18n', '~> 0.6'
  spec.add_dependency 'json-schema', '~> 2.5.0'

  spec.add_development_dependency 'bundler', '~> 1.6'
  spec.add_development_dependency 'rake'

  spec.add_development_dependency 'rspec', '~> 3'
  spec.add_development_dependency 'rspec-its', '~> 1.1.0'
  spec.add_development_dependency 'vcr', '~> 2.9.3'
  spec.add_development_dependency 'webmock', '~> 1', '>= 1.17.3'
  spec.add_development_dependency 'tins', '~> 1.6.0'
end
