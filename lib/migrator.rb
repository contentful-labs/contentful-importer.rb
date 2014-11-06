require_relative 'exporters/database/export'
require_relative 'importer/data_organizer'
require_relative 'importer/parallel_importer'
require_relative 'configuration'
require_relative 'converter'

class Migrator
  attr_reader :importer, :exporter, :converter, :data_organizer

  def initialize(settings, exporter = nil)
    @config = Contentful::Configuration.new(settings)
    @exporter = exporter || Contentful::Exporter::Database::Export.new(@config)
    @importer = Contentful::ParallelImporter.new(@config)
    @converter = Contentful::Converter.new(@config)
    @data_organizer = Contentful::DataOrganizer.new(@config)
  end

  def run(action, options = {})
    case action.to_s
      when '--content-types-json'
        exporter.create_content_type_json
      when '--export-json'
        exporter.save_data_as_json
      when '--prepare-json'
        exporter.create_data_relations
      when '--organize-files'
        data_organizer.execute(options[:thread])
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
