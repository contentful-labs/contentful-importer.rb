require_relative 'migrator'
require 'yaml'

module Contentful
	module Importer
	  class CLI < Escort::ActionCommand::Base

	    def execute
	      setting_file = YAML.load_file(global_options[:file])
	      Migrator.new(setting_file).run(command_name, command_options)
	    end

	  end
	end
end
