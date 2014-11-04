require 'fileutils'
require 'thread'
require_relative '../../../lib/importer/worker/worker_importer'
module Contentful
  class Worker

    THREADS_COUNT = 5

    attr_reader :config,
                :data_dir,
                :collections_dir,
                :entries_dir,
                :threads_dir,
                :worker_importer

    def initialize(settings)
      @worker_importer = Contentful::WorkerImporter.new(settings)
      @config = settings
      @data_dir = config['data_dir']
      @collections_dir = "#{data_dir}/collections"
      @entries_dir = "#{data_dir}/entries"
      @threads_dir = "#{data_dir}/threads"
    end

    def execute
      create_threads_subdirectories

      total_count = Dir.glob("#{entries_dir}/**/*.json").count

      per_thread_count = total_count / THREADS_COUNT
      current_thread = 0
      entries = 0

      Dir.glob("#{entries_dir}/*") do |dir_path|
        collection_name = File.basename(dir_path)
        if File.exist?("#{collections_dir}/#{collection_name}.json")
          collection_attributes = JSON.parse(File.read("#{collections_dir}/#{collection_name}.json"))
          content_type_id = collection_attributes['id']
          puts "Processing collection: #{collection_name}"
          Dir.glob("#{dir_path}/*.json") do |entry_path|
            name = "#{content_type_id}_#{File.basename(entry_path, '.*').match(/(\d+)/)[0]}.json"
            FileUtils.mv entry_path, "#{threads_dir}/#{current_thread}/#{name}"
            entries += 1
            if entries == per_thread_count
              entries = 0
              current_thread += 1
            end
          end
        end
      end
      create_threads
    end

    def create_threads
      threads_paths = Dir.glob("#{threads_dir}/*").each_with_object([]) do |dir_path, thread_paths|
        thread_paths << dir_path
      end

      threads = threads_paths.each_with_object([]) do |thread_path, threads|
        threads << Thread.new do
          worker_importer.send(:import_entries, thread_path)
        end
      end

      threads.each do |thread|
        thread.join
      end
    end

    def create_threads_subdirectories
      create_directory(threads_dir)
      THREADS_COUNT.times do |thread_id|
        create_directory("#{threads_dir}/#{thread_id}")
      end
    end

    def create_directory(path)
      FileUtils.mkdir_p(path) unless File.directory?(path)
    end

  end
end