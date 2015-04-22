require 'active_support/core_ext/hash'
module Contentful
  module Importer
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
                  :space_id

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
      end

      def validate_required_parameters
        fail ArgumentError, 'Set PATH to data_dir. Folder where all data will be stored. View README' if config['data_dir'].nil?
      end
    end
  end
end
