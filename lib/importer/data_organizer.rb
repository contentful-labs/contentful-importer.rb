require 'fileutils'
require 'thread'
require_relative 'parallel_importer'

module Contentful
  class DataOrganizer

    attr_reader :config

    def initialize(settings)
      @config = settings
    end

    def execute(threads_count)
      create_threads_subdirectories(threads_count)
      split_entries(threads_count)
    end

    def split_entries(threads_count)
      entries_per_thread_count = count_files / threads_count
      current_thread, entry_index = 0, 0
      Dir.glob("#{config.entries_dir}/*") do |dir_path|
        collection_name = File.basename(dir_path)
        if has_contentful_structure?(collection_name) && collection_name == 'rezept_ausgabe'
          content_type_id = content_type_id_from_file(collection_name)
          # organize_entries(content_type_id, current_thread, dir_path, entry_index, entries_per_thread_count)
          puts "Processing collection: #{content_type_id}"
          Dir.glob("#{dir_path}/*.json") do |entry_path|
            copy_entry(entry_path, current_thread, content_type_id)
            entry_index += 1
            if entry_index == entries_per_thread_count
              entry_index = 0
              current_thread += 1
              if current_thread == threads_count
                current_thread = 0
              end
            end
          end
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

    def total_entries_count
      Dir.glob("#{config.entries_dir}/**/*.json").count
    end

    def create_threads_subdirectories(threads_count)
      create_directory(config.threads_dir)
      threads_count.times do |thread_id|
        create_directory("#{config.threads_dir}/#{thread_id}")
      end
    end

    def create_directory(path)
      FileUtils.mkdir_p(path) unless File.directory?(path)
    end


    def count_files
      total_number = 0
      Dir.glob("#{config.entries_dir}/*") do |dir_path|
        collection_name = File.basename(dir_path)
        if has_contentful_structure?(collection_name)  && collection_name == 'rezept_ausgabe'
          total_number += Dir.glob("#{config.entries_dir}/#{collection_name}/*").count
        end
      end
      total_number
    end
  end
end