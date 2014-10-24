require_relative 'exporters/database/database'
require_relative 'importer/importer'

class Migrator
  attr_reader :importer, :exporter

  MESSAGE = <<-eoruby
Actions:
  1. Export data to JSON files.
  2. Prepare JSON files for importing.
  3. Import data to Contentful.
  9. Test credentials.
-> Choose on of the options:
  eoruby

  def initialize(exporter = nil)
    @exporter = exporter || Contentful::Exporter::Database.new
    @importer = Contentful::Importer.new
  end

  def run
    puts MESSAGE
    action_choice = gets.to_i
    case action_choice
      when 1
        exporter.export_data
        exporter.save_data_as_json
      when 2
        exporter.create_data_relations
      when 3
        importer.execute
      when 9
        importer.test_credentials
    end
  end
end
