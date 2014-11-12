require_relative 'migrator'
require 'yaml'

# module Command
#   class CLI < Escort::ActionCommand::Base
#
#     def execute
#       setting_file = YAML.load_file(global_options[:file])
#       Migrator.new(setting_file).run(command_name, command_options)
#     end
#
#   end
# end

# # REMOVE AFTER TESTS
setting_file = YAML.load_file('data/settings.yml')
# Migrator.new(setting_file).run('--export-json')
#
Migrator.new(setting_file).run('--prepare-json')
# # # Migrator.new(setting_file).run('--import-content-types', space_name: 'testingImport' )
# Migrator.new(setting_file).run('--convert-json')
# # Migrator.new(setting_file).run('--import')