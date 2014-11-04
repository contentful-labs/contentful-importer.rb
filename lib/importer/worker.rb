require 'fileutils'
module Contentful
  class Worker

    THREADS_COUNT = 5

    attr_reader :config,
                :data_dir,
                :collections_dir,
                :entries_dir

    def initialize(settings)
      @config = settings
      @data_dir = config['data_dir']
      @collections_dir = "#{data_dir}/collections"
      @entries_dir = "#{data_dir}/entries"
    end

    def execute

      total_count =  Dir.glob("#{entries_dir}/**/*.json").count

      per_thread_count = total_count / THREADS_COUNT

      FileUtils.mkdir_p("#{data_dir}/threads")  unless File.directory?("#{data_dir}/threads")
      THREADS_COUNT.times do |thread_id|
        FileUtils.mkdir_p("#{data_dir}/threads/#{thread_id}") unless File.directory?("#{data_dir}/threads/#{thread_id}")
      end


      current_thread = 0
      entries = 0
      Dir.glob("#{entries_dir}/*") do |dir_path|
        collection_name = File.basename(dir_path)
        collection_attributes = JSON.parse(File.read("#{collections_dir}/#{collection_name}.json"))
        content_type_id = collection_attributes['content_type_id']
        puts "Processing collection: #{content_type_id}"
        Dir.glob("#{dir_path}/*.json") do |entry_path|
          name = "#{content_type_id}_#{File.basename(entry_path, '.*').match(/(\d+)/)[0]}.json"
          FileUtils.mv entry_path, "#{data_dir}/threads/#{current_thread}/#{name}"
          entries += 1
          if entries == per_thread_count
            entries = 0
            current_thread += 1
          end
        end

      end



      # do |dir_path|
      #   collection_name = File.basename(dir_path)
      #   puts "Importing entries for #{collection_name}."
      #   collection_attributes = JSON.parse(File.read("#{collections_dir}/#{collection_name}.json"))
      #   content_type_id = collection_attributes['content_type_id']
      #   space_id = collection_attributes['space_id']
      #   import_entries_for_collection(content_type_id, dir_path, space_id)
      # end


    end
  end


end