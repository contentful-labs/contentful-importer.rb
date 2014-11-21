module Contentful
  class Configuration
    attr_reader :space_id,
                :config,
                :data_dir,
                :collections_dir,
                :entries_dir,
                :assets_dir,
                :time_logs_dir,
                :success_logs_dir,
                :failure_logs_dir,
                :threads_dir,
                :imported_entries,
                :published_entries,
                :contentful_structure,
                :mapping,
                :db,
                :helpers_dir,
                :tables,
                :content_types,
                :import_form_dir

    def initialize(settings)
      @config = settings
      @data_dir = config['data_dir']
      @collections_dir = "#{data_dir}/collections"
      @entries_dir = "#{data_dir}/entries"
      @assets_dir = "#{data_dir}/assets"
      @time_logs_dir = "#{data_dir}/logs/time.json"
      @success_logs_dir = "#{data_dir}/logs"
      @failure_logs_dir = "#{data_dir}/logs"
      @threads_dir = "#{data_dir}/threads"
      @imported_entries = []
      @published_entries = []
      @space_id = config['space_id']
      @helpers_dir = "#{data_dir}/helpers"
      create_structure_files
      @contentful_structure = JSON.parse(File.read(config['contentful_structure_dir']), symbolize_names: true).with_indifferent_access
      @mapping = JSON.parse(File.read(config['mapping_dir']), symbolize_names: true).with_indifferent_access
      @tables = config['mapped']['tables']
      @db = Sequel.connect(:adapter => config['adapter'], :user => config['user'], :host => config['host'], :database => config['database'], :password => config['password'])
      @import_form_dir = config['import_form_dir']
      @content_types = config['json_with_content_types']
    end

    def create_structure_files
      File.open(config['contentful_structure_dir'], 'w') { |file| file.write({}) } unless File.exist?(config['contentful_structure_dir'])
      File.open(config['mapping_dir'], 'w') { |file| file.write({}) } unless File.exist?(config['mapping_dir'])
    end

  end
end