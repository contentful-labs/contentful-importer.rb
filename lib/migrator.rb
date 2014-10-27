require_relative 'exporters/database/export'
require_relative 'importer/importer'
require_relative 'converter'
class Migrator
  attr_reader :importer, :exporter, :converter

  MESSAGE = <<-eoruby
Actions:
  1. Export data to JSON files.
  2. Prepare JSON files for importing.
  3. Import data to Contentful.
  8. Parse JSON file to import form/
  9. Test credentials.
-> Choose on of the options:
  eoruby

  def initialize(exporter = nil)
    @exporter = exporter || Contentful::Exporter::Database::Export.new
    @importer = Contentful::Importer.new
    @converter = Contentful::Converter.new
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
      when 8
        converter.convert_to_import_form
      when 9
        importer.test_credentials
    end
  end
end
