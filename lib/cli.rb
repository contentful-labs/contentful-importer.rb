require_relative 'migrator'
require 'yaml'

module Command
  class CLI < Escort::ActionCommand::Base

    def execute
      puts command_options
      setting_file = YAML.load_file(global_options[:file])
      Migrator.new(setting_file).run(command_name, command_options)
    end

  end
end

# setting_file = YAML.load_file('settings.yml')
# # Migrator.new(setting_file).run('--export-json')
# # Migrator.new(setting_file).run('--prepare-json')
# Migrator.new(setting_file).run('--import-content-types')
# # Migrator.new(setting_file).run('--import',count: 1)