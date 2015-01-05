require 'simplecov'
SimpleCov.start 'rails'

require 'bundler/setup'
Bundler.setup

require 'rspec'
require 'rspec/its'
require 'yaml'
require 'json'

Dir[File.dirname(__FILE__) + '/support/*.rb'].each { |f| require f }