require 'fileutils'
require 'thread'
require_relative 'parallel_importer'

module Contentful
  class Worker

    attr_reader :config,
                :data_dir,
                :collections_dir,
                :entries_dir,
                :threads_dir,
                :space_id

    def initialize(settings)
      @config = settings
      @space_id = config['space_id']
      @data_dir = config['data_dir']
      @collections_dir = "#{data_dir}/collections"
      @entries_dir = "#{data_dir}/entries"
      @threads_dir = "#{data_dir}/threads"
    end

    #TODO extract import_entries to own action
    def execute(threads_count)
      create_threads_subdirectories(threads_count)
      split_entries(threads_count)
      import_in_threads(threads_count)
    end

    def split_entries(threads_count)
      total_count = Dir.glob("#{entries_dir}/**/*.json").count

      per_thread_count = total_count / threads_count
      current_thread = 0
      entries = 0

      #TODO REFACTOR AFTER SOLVING PROBLEM WITH KEEPING 'REST' ENTRIES
      Dir.glob("#{entries_dir}/*") do |dir_path|
        collection_name = File.basename(dir_path)
        if File.exist?("#{collections_dir}/#{collection_name}.json")
          collection_attributes = JSON.parse(File.read("#{collections_dir}/#{collection_name}.json"))
          content_type_id = collection_attributes['id']
          puts "Processing collection: #{collection_name}"
          Dir.glob("#{dir_path}/*.json") do |entry_path|
            name = "#{content_type_id}_#{File.basename(entry_path, '.*').match(/(\d+)/)[0]}.json"
            FileUtils.cp entry_path, "#{threads_dir}/#{current_thread}/#{name}"
            entries += 1
            #TODO keep the rest!
            if entries == per_thread_count
              entries = 0
              current_thread += 1
            end
          end
        end
      end
    end

    def import_in_threads(threads_count)
      threads = []
      threads_count.times do |thread_id|
        threads << Thread.new do
          Contentful::ParallelImporter.new(config).send(:import_entries, "#{threads_dir}/#{thread_id}", space_id)
        end
      end
      threads.each do |thread|
        thread.join
      end
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