require 'active_support/core_ext/hash'
module Contentful
  class Configuration
    attr_reader :space_id,
                :config,
                :data_dir,
                :collections_dir,
                :entries_dir,
                :assets_dir,
                :log_files_dir,
                :threads_dir,
                :imported_entries,
                :published_entries,
                :published_assets,
                :contentful_structure,
                :converted_model_dir,
                :space_id,
                :content_types

    def initialize(settings)
      @config = settings
      validate_required_parameters
      @data_dir = settings['data_dir']
      @collections_dir = "#{data_dir}/collections"
      @entries_dir = "#{data_dir}/entries"
      @assets_dir = "#{data_dir}/assets"
      @log_files_dir = "#{data_dir}/logs"
      @threads_dir = "#{data_dir}/threads"
      @imported_entries = []
      @published_entries = []
      @published_assets = []
      @space_id = settings['space_id']
      @contentful_structure = load_contentful_structure_file
      @converted_model_dir = settings['converted_model_dir']
      @content_types = settings['content_model_json']
    end

    def validate_required_parameters
      fail ArgumentError, 'Set PATH to data_dir. Folder where all data will be stored. View README' if config['data_dir'].nil?
      fail ArgumentError, 'Set PATH to contentful structure JSON file. View README' if config['contentful_structure_dir'].nil?
    end

    # If contentful_structure JSON file exists, it will load the file. If not, it will automatically create an empty file.
    # This file is required to convert contentful model to contentful import structure.
    def load_contentful_structure_file
      file_exists? ? load_existing_contentful_structure_file : create_empty_contentful_structure_file
    end

    def file_exists?
      File.exists?(config['contentful_structure_dir'])
    end

    def create_empty_contentful_structure_file
      File.open(config['contentful_structure_dir'], 'w') { |file| file.write({}) }
      load_existing_contentful_structure_file
    end

    def load_existing_contentful_structure_file
      JSON.parse(File.read(config['contentful_structure_dir']), symbolize_names: true).with_indifferent_access
    end
  end
end
