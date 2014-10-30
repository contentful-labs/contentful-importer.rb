require_relative 'migrator'
require 'yaml'

module Command
  class CLI < Escort::ActionCommand::Base

    def execute
      $setting_file = YAML.load_file(global_options[:file])
      Migrator.new.run(command_name)
    end

  end
end