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

    def initialize(settings, exporter)
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
      validate_required_parameters(exporter)
      @contentful_structure = JSON.parse(File.read(config['contentful_structure_dir']), symbolize_names: true).with_indifferent_access
      @db = adapter_setup(exporter)
      @import_form_dir = config['import_form_dir']
      @content_types = config['content_model_json']
    end

    def validate_required_parameters(exporter)
      case exporter
        when 'database'
          defined_contentful_structure
          defined_mapping_structure
          define_adapter
        when 'wordpress'
          defined_contentful_structure
      end
    end

    def defined_contentful_structure
      fail ArgumentError, 'Set PATH to contentful structure JSON file. Check README' if config['contentful_structure_dir'].nil?
    end

    def defined_mapping_structure
      fail ArgumentError, 'Set PATH to mapping structure JSON file. Check README' if config['mapping_dir'].nil?
    end

    def define_adapter
      %w(adapter user host database).each do |param|
        fail ArgumentError, "Set database connection parameters [adapter, host, database, user, password]. Missing the '#{param}' parameter! Password is optional. Check README!" unless config[param]
      end
    end

    def adapter_setup(exporter)
      if exporter == 'database'
        Sequel.connect(:adapter => config['adapter'], :user => config['user'], :host => config['host'], :database => config['database'], :password => config['password'])
      end
    end
  end
end