require_relative 'exporters/database/export'
require_relative 'importer/worker/worker'
require_relative 'importer/worker/parallel_importer'
require_relative 'converter'

class Migrator
  attr_reader :importer, :exporter, :converter, :worker

  def initialize(settings, exporter = Contentful::Exporter::Database::Export.new(settings))
    @exporter = exporter
    @importer = Contentful::ParallelImporter.new(settings)
    @converter = Contentful::Converter.new(settings)
    @worker = Contentful::Worker.new(settings)
  end

  def run(action, options = {})
    case action.to_s
      when '--export-json'
        exporter.export_data
        exporter.save_data_as_json
      when '--prepare-json'
        exporter.create_data_relations
      when '--import-content-types'
        importer.execute
      when '--import'
        worker.execute(options[:count])
      when '--convert-json'
        converter.convert_to_import_form
      when '--test-credentials'
        importer.test_credentials
      when '--list-tables'
        exporter.tables_name
    end
  end
end
