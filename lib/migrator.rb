require_relative 'database/database_exporter'
require_relative 'importer'
require 'contentful/management'
require 'fileutils'

class Migrator
  attr_reader :importer, :database_exporter

  MESSAGE = <<-eoruby
Actions:
  1. Export data from Database to JSON files.
  2. Transform JSON files to import form.
  9. Test credentials.
-> Choose on of the options:
  eoruby

  def run
    puts MESSAGE
    action_choice = gets.to_i
    case action_choice
      when 1
        database_exporter.export_models_from_database
        database_exporter.save_objects_as_json
      when 2
        database_exporter.create_contentful_links
      when 9
        importer.test_credentials
    end
  end

  def database_exporter
    @database_exporter ||= Database::Exporter.new
  end

  def importer
    @importer ||= Importer.new
  end
end
