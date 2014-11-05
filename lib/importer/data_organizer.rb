require 'fileutils'
require 'thread'
require_relative 'parallel_importer'

module Contentful
  class DataOrganizer

    attr_reader :config,
                :data_dir,
                :collections_dir,
                :entries_dir,
                :threads_dir

    def initialize(settings)
      @config = settings
      @data_dir = config['data_dir']
      @collections_dir = "#{data_dir}/collections"
      @entries_dir = "#{data_dir}/entries"
      @threads_dir = "#{data_dir}/threads"
    end

    def execute(threads_count)
      create_threads_subdirectories(threads_count)
      split_entries(threads_count)
    end

    def split_entries(threads_count)
      entries_per_thread_count = total_entries_count / threads_count
      current_thread, entry_index = 0

      Dir.glob("#{entries_dir}/*") do |dir_path|
        collection_name = File.basename(dir_path)
        if has_contentful_structure?(collection_name)
          content_type_id = content_type_id_from_file(collection_name)
          organize_entries(content_type_id, current_thread, dir_path, entry_index, entries_per_thread_count)
        end
      end
    end

    def organize_entries(content_type_id, current_thread, dir_path, entry_index, entries_per_thread_count)
      puts "Processing collection: #{content_type_id}"
      Dir.glob("#{dir_path}/*.json") do |entry_path|
        copy_entry(entry_path, current_thread, content_type_id)
        entry_index += 1
        if entry_index == entries_per_thread_count
          entry_index = 0
          current_thread += 1
        end
      end
    end

    def has_contentful_structure?(collection_file)
      File.exist?("#{collections_dir}/#{collection_file}.json")
    end

    def content_type_id_from_file(collection_file)
      JSON.parse(File.read("#{collections_dir}/#{collection_file}.json"))['id']
    end

    def new_entry_name(content_type_id, entry_path)
      "#{content_type_id}_#{File.basename(entry_path, '.*').match(/(\d+)/)[0]}.json"
    end

    def copy_entry(entry_path, current_thread, content_type_id)
      FileUtils.cp entry_path, "#{threads_dir}/#{current_thread}/#{new_entry_name(content_type_id, entry_path)}"
    end

    def total_entries_count
      Dir.glob("#{entries_dir}/**/*.json").count
    end

    def create_threads_subdirectories(threads_count)
      create_directory(threads_dir)
      threads_count.times do |thread_id|
        create_directory("#{threads_dir}/#{thread_id}")
      end
    end

    def create_directory(path)
      FileUtils.mkdir_p(path) unless File.directory?(path)
    end

  end
end