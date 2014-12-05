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
      class Export

        include Contentful::Exporter::Database::DataExport
        include Contentful::Exporter::Database::JsonExport
        include Contentful::Exporter::Database::RelationsExport
        include Contentful::Exporter::Database::Utils

        Sequel::Model.plugin :json_serializer

        attr_reader :config, :mapping, :tables

        def initialize(settings)
          @config = settings
          @mapping = mapping_structure
          @tables = load_tables
        end

        def tables_name
          create_directory(config.data_dir)
          write_json_to_file("#{config.data_dir}/table_names.json", config.db.tables)
          puts "File with name of tables saved to #{"#{config.data_dir}/table_names.json"}"
        end

        def create_content_type_json
          config.contentful_structure.each do |content_type, values|
            content_type_name = content_type_name(content_type)
            create_directory(config.collections_dir)
            create_content_type_json_file(content_type_name, values)
          end
        end

        def save_data_as_json
          tables.each do |table|
            model_name = table.to_s.camelize
            content_type_name = mapping[model_name][:content_type]
            save_object_to_file(table, content_type_name, model_name, asset?(model_name) ? config.assets_dir : config.entries_dir)
          end
        end

        def create_data_relations
          relations_from_mapping.each do |model_name, relations|
            generate_relations_helper_indexes(relations)
            map_relations_to_links(model_name, relations)
          end
        end

        def mapping_structure
          fail ArgumentError, 'Set PATH to contentful structure JSON file. Check README' unless config.config['mapping_dir']
          JSON.parse(File.read(config.config['mapping_dir']), symbolize_names: true).with_indifferent_access
        end

        def load_tables
          fail ArgumentError, 'Before importing data from tables, define their names. Check README!' unless config.config['mapped'] && config.config['mapped']['tables']
          config.config['mapped']['tables']
        end

      end
    end
  end
end