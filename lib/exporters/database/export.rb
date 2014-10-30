require 'active_support/core_ext/string'
require 'active_support/core_ext/hash/compact'
require 'active_support/core_ext/hash'
require 'fileutils'
require 'sequel'
require_relative 'modules/data_export'
require_relative 'modules/json_export'
require_relative 'modules/relations_export'
require_relative 'modules/utils'

module Contentful
  module Exporter
    module Database
      class Export ##TODO CHANGE NAME

        include Contentful::Exporter::Database::DataExport
        include Contentful::Exporter::Database::JsonExport
        include Contentful::Exporter::Database::RelationsExport
        include Contentful::Exporter::Database::Utils

        Sequel::Model.plugin :json_serializer

        attr_reader :contentful_structure,
                    :mapping,
                    :config,
                    :db,
                    :data_dir,
                    :collections_dir,
                    :entries_dir,
                    :assets_dir,
                    :helpers_dir,
                    :tables

        def initialize(settings)
          @config = settings
          @data_dir = config['data_dir']
          @collections_dir = "#{data_dir}/collections"
          @entries_dir = "#{data_dir}/entries"
          @assets_dir = "#{data_dir}/assets"
          @helpers_dir = "#{data_dir}/helpers"

          @contentful_structure = JSON.parse(File.read(config['contentful_structure_dir']), symbolize_names: true).with_indifferent_access
          @mapping = JSON.parse(File.read(config['mapping_dir']), symbolize_names: true).with_indifferent_access
          @tables = config['mapped']['tables']

          @db = Sequel.connect(:adapter => config['adapter'], :user => config['user'], :host => config['host'], :database => config['database'], :password => config['password'])
        end

        def tables_name
          write_json_to_file("#{data_dir}/tables.json", db.tables)
        end

        def export_data
          contentful_structure.each do |content_type, values|
            content_type_name = content_type_name(content_type)
            create_directory(collections_dir)
            create_content_type_json_file(content_type_name, values)
          end
        end

        def save_data_as_json
          tables.each do |table|
            model_name = table.to_s.camelize
            content_type_name = mapping[model_name][:content_type].underscore
            save_object_to_file(table, content_type_name, model_name, asset?(model_name) ? assets_dir : entries_dir)
          end
        end

        def create_data_relations
          relations_from_mapping.each do |model_name, relations|
            generate_relations_helper_indexes(relations)
            map_relations_to_links(model_name, relations)
          end
        end

      end
    end
  end
end