require_relative 'exporters/database/export'
require_relative 'importer/importer'
require_relative 'converter'

class Migrator
  attr_reader :importer, :exporter, :converter, :settings

  def initialize(settings, exporter = Contentful::Exporter::Database::Export.new(settings))
    @settings = settings
    @exporter = exporter
    @importer = Contentful::Importer.new(settings)
    @converter = Contentful::Converter.new(settings)
  end

  def run(option)
    case option.to_s
      when '--export-json'
        exporter.export_data
        exporter.save_data_as_json
      when '--prepare-json'
        exporter.create_data_relations
      when '--import'
        importer.execute
      when '--convert-json'
        converter.convert_to_import_form
      when '--test-credentials'
        importer.test_credentials
      when '--list-tables'
        exporter.tables_name
    end
  end
end
