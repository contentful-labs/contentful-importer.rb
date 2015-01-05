require_relative 'importer/data_organizer'
require_relative 'importer/parallel_importer'
require_relative 'configuration'
require_relative 'converters/contentful_model_to_json'
require_relative 'json_schema_validator'

class Migrator

  attr_reader :importer, :converter, :data_organizer, :config, :json_validator

  def initialize(settings)
    @config = Contentful::Configuration.new(settings)
    @importer = Contentful::ParallelImporter.new(@config)
    @converter = Contentful::Converter::ContentfulModelToJson.new(@config)
    @data_organizer = Contentful::DataOrganizer.new(@config)
    @json_validator = Contentful::JsonSchemaValidator.new(@config)
  end

  def run(action, options = {})
    case action.to_s
      when '--create-contentful-model-from-json'
        converter.create_content_type_json
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
      when '--import-assets'
        importer.import_only_assets
      when '--publish-assets'
        importer.publish_assets
      when '--validate-schema'
        json_validator.validate_schemes
    end
  end
end
