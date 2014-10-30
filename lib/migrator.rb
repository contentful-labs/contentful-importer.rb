require_relative 'exporters/database/export'
require_relative 'importer/importer'
require_relative 'converter'

class Migrator
  attr_reader :importer, :exporter, :converter

  def initialize(exporter = nil)
    @exporter = exporter || Contentful::Exporter::Database::Export.new
    @importer = Contentful::Importer.new
    @converter = Contentful::Converter.new
  end

  def run(options)
    case options
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
    end
  end
end
