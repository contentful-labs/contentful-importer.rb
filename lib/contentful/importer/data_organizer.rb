require 'fileutils'
require 'thread'
require_relative 'parallel_importer'

module Contentful
  module Importer
    class DataOrganizer

      attr_reader :config, :split_params, :logger

      def initialize(settings)
        @config = settings
        @split_params = {object_index: 0, current_thread: 0}
        @logger = Logger.new(STDOUT)
      end

      def execute(threads_count)
        create_threads_subdirectories(threads_count, true)
        split_entries(threads_count)
      end

      def split_assets_to_threads(threads_count)
        create_threads_subdirectories(threads_count, false, {assets: 'assets/'})
        split_assets(threads_count)
      end

      def split_entries(threads_count)
        entries_per_thread_count = total_entries_count / threads_count
        Dir.glob("#{config.entries_dir}/*") do |dir_path|
          collection_name = File.basename(dir_path)
          if has_contentful_structure?(collection_name)
            content_type_id = content_type_id_from_file(collection_name)
            process_collection_files(content_type_id, dir_path, entries_per_thread_count, threads_count)
          end
        end
      end

      def split_assets(threads_count)
        asset_per_thread = total_assets_count / threads_count
        Dir.glob("#{config.assets_dir}/**/*json") do |asset_path|
          copy_asset(asset_path)
          split_params[:object_index] += 1
          count_index_files(asset_per_thread, threads_count)
        end
      end

      def process_collection_files(content_type_id, dir_path, entries_per_thread_count, threads_count)
        logger.info "Processing collection: #{content_type_id}"
        Dir.glob("#{dir_path}/*.json") do |entry_path|
          copy_entry(entry_path, split_params[:current_thread], content_type_id)
          split_params[:object_index] += 1
          count_index_files(entries_per_thread_count, threads_count)
        end
      end

      def count_index_files(objects_per_thread_count, threads_count)
        if split_params[:object_index] == objects_per_thread_count
          split_params[:object_index] = 0
          set_current_thread(threads_count)
        end
      end

      def set_current_thread(threads_count)
        split_params[:current_thread] += 1
        split_params[:current_thread] = 0 if split_params[:current_thread] == threads_count
      end

      def has_contentful_structure?(collection_file)
        File.exist?("#{config.collections_dir}/#{collection_file}.json")
      end

      def content_type_id_from_file(collection_file)
        JSON.parse(File.read("#{config.collections_dir}/#{collection_file}.json"))['id']
      end

      def new_entry_name(content_type_id, entry_path)
        "#{content_type_id}_#{File.basename(entry_path, '.*').match(/(\d+)/)[0]}.json"
      end

      def copy_entry(entry_path, current_thread, content_type_id)
        FileUtils.cp entry_path, "#{config.threads_dir}/#{current_thread}/#{new_entry_name(content_type_id, entry_path)}"
      end

      def copy_asset(asset_path)
        FileUtils.cp asset_path, "#{config.threads_dir}/assets/#{split_params[:current_thread]}/#{File.basename(asset_path)}"
      end

      def create_threads_subdirectories(threads_count, validate, dir = {})
        validate_collections_files if validate
        create_directory(config.threads_dir)
        threads_count.times do |thread_id|
          create_directory("#{config.threads_dir}/#{dir[:assets]}#{thread_id}")
        end
      end

      def create_directory(path)
        FileUtils.mkdir_p(path) unless File.directory?(path)
      end

      def total_entries_count
        total_number = 0
        Dir.glob("#{config.entries_dir}/*") do |dir_path|
          collection_name = File.basename(dir_path)
          total_number += Dir.glob("#{config.entries_dir}/#{collection_name}/*").count if has_contentful_structure?(collection_name)
        end
        total_number
      end

      def total_assets_count
        Dir.glob("#{config.assets_dir}/**/*json").count
      end

      def validate_collections_files
        fail ArgumentError, "Make sure the #{config.collections_dir} directory exists and the content structure resides within it. View README" unless Dir.exist?(config.collections_dir)
        fail ArgumentError, 'Collections directory is empty! Create content types JSON files. View README' if Dir.glob("#{config.collections_dir}/*").empty?
      end
    end
  end
end