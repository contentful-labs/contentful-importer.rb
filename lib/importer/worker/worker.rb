require 'fileutils'
require 'thread'
require_relative 'worker_importer'

module Contentful
  class Worker

    THREADS_COUNT = 5

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

    def execute
      # create_threads_subdirectories
      # split_entries
      import_in_threads
    end

    def split_entries
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

    def import_in_threads
      threads = []
      THREADS_COUNT.times do |thread_id|
        threads << Thread.new do
          Contentful::WorkerImporter.new(config).send(:import_entries2, "#{threads_dir}/#{thread_id}")
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