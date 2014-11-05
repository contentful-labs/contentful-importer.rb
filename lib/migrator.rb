require_relative 'exporters/database/export'
require_relative 'importer/data_organizer'
require_relative 'importer/parallel_importer'
require_relative 'converter'

class Migrator
  attr_reader :importer, :exporter, :converter, :data_organizer

  def initialize(settings, exporter = Contentful::Exporter::Database::Export.new(settings))
    @exporter = exporter
    @importer = Contentful::ParallelImporter.new(settings)
    @converter = Contentful::Converter.new(settings)
    @data_organizer = Contentful::DataOrganizer.new(settings)
  end

  def run(action, options = {})
    case action.to_s
      when '--export-json'
        exporter.export_data
        exporter.save_data_as_json
      when '--prepare-json'
        exporter.create_data_relations
      when '--organize-files'
        data_organizer.execute(options[:count])
      when '--import-content-types'
        importer.create_contentful_model(options)
      when '--import'
        importer.import_data
      when '--convert-json'
        converter.convert_to_import_form
      when '--test-credentials'
        importer.test_credentials
      when '--list-tables'
        exporter.tables_name
    end
  end
end
