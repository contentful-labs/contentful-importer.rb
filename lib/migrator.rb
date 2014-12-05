require_relative 'exporters/database/export'
require_relative 'exporters/wordpress/export'
require_relative 'importer/data_organizer'
require_relative 'importer/parallel_importer'
require_relative 'configuration'
require_relative 'converter'


class Migrator

  attr_reader :importer, :exporter, :converter, :data_organizer, :config

  def initialize(settings, exporter)
    @config = Contentful::Configuration.new(settings, exporter)
    @exporter = initialize_exporter(exporter)
    @importer = Contentful::ParallelImporter.new(@config)
    @converter = Contentful::Converter.new(@config)
    @data_organizer = Contentful::DataOrganizer.new(@config)
  end

  def initialize_exporter(option)
    case option
      when 'database'
        Contentful::Exporter::Database::Export.new(config)
      when 'wordpress'
        Contentful::Exporter::Wordpress::Export.new(config)
      else
        fail ArgumentError, 'Invalid Exporter - Check README!'
    end
  end

  def run(action, options = {})
    case action.to_s
      when '--create-content-model-from-json'
        exporter.create_content_type_json
      when '--export-json'
        exporter.save_data_as_json
      when '--prepare-json'
        exporter.create_data_relations
      when '--threads'
        data_organizer.execute(options[:thread])
      when '--import-content-types'
        importer.create_contentful_model(options)
      when '--import'
        importer.import_data
      when '--convert-content-model-to-json'
        converter.convert_to_import_form
      when '--publish-entries'
        importer.publish_entries_in_threads
      when '--test-credentials'
        importer.test_credentials
      when '--list-tables'
        exporter.tables_name
      when '--import-assets'
        importer.import_only_assets
      when '--extract-wordpress-blog-json'
        exporter.export_blog
    end
  end
end
