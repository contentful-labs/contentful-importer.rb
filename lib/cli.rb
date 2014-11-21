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

# # # # REMOVE AFTER TESTS
setting_file = YAML.load_file('data/settings.yml')
# Migrator.new(setting_file).run('--export-json')
# Migrator.new(setting_file).run('--prepare-json')
# Migrator.new(setting_file).run('--recipes-special-mapping')
# Migrator.new(setting_file).run('--organize-files',thread: 5)
# Migrator.new(setting_file).run('--import-content-types', space_id: "l9qj50bqgqik" )
# Migrator.new(setting_file).run('--convert-json')
Migrator.new(setting_file).run('--import')
# Migrator.new(setting_file).run('--import-assets')
# Migrator.new(setting_file).run('--publish-entries')
# Migrator.new(setting_file).run('--content-types-json')
