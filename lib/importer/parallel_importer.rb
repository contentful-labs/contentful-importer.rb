
require_relative 'mime_content_type'
require 'contentful/management'
require 'csv'
require 'yaml'
require 'api_cache'
module Contentful
  class ParallelImporter

    Encoding.default_external = 'utf-8'

    ASSETS_IDS = []
    attr_reader :space,
                :config
    attr_accessor :content_type

    def initialize(settings)
      @config = settings
      Contentful::Management::Client.new(config.config['access_token'], default_locale: config.config['default_locale'] )
    end

    def create_contentful_model(space)
      initialize_space(space)
      import_content_types
    end

    def import_data
      import_in_threads
    end

    def test_credentials
      space = Contentful::Management::Space.all
      if space.is_a? Contentful::Management::Array
        puts 'Contentful Management API credentials: OK'
      end
    rescue NoMethodError => _error
      puts 'Contentful Management API credentials: INVALID (check README)'
    end

    def number_of_threads
      Dir.glob("#{config.threads_dir}/*").count
    end

    def import_in_threads
      threads = []
      number_of_threads.times do |thread_id|
        threads << Thread.new do
          self.class.new(config).import_entries("#{config.threads_dir}/#{thread_id}", config.space_id)
        end
      end
      threads.each do |thread|
        thread.join
      end
    end

    def import_entries(path, space_id)
      log_file_name = "success_thread_#{File.basename(path)}"
      create_log_file(log_file_name)
      load_log_files
      Dir.glob("#{path}/*.json") do |entry_path|
        content_type_id = File.basename(entry_path).match(/(.+)_\d+/)[1]
        entry_file_name = File.basename(entry_path)
        import_entry(entry_path, space_id, content_type_id, log_file_name) unless config.imported_entries.flatten.include?(entry_file_name)
      end
    end

    def import_only_assets
      create_log_file('assets_log')
      ASSETS_IDS << CSV.read("#{config.data_dir}/logs/assets_log.csv", 'r')
      Dir.glob("#{config.assets_dir}/**/*json") do |file_path|
        asset_attributes = JSON.parse(File.read(file_path))
        if asset_attributes['url'] && asset_attributes['url'].start_with?('http') && !ASSETS_IDS.flatten.include?(asset_attributes['id'])
          puts "Import asset - #{asset_attributes['id']} "
          asset_title = asset_attributes['name'].present? ? asset_attributes['name'] : asset_attributes['id']
          asset_file = create_asset_file(asset_title, asset_attributes)
          space = Contentful::Management::Space.find(config.config['space_id'])
          asset = space.assets.create(id: "#{asset_attributes['id']}", title: "#{asset_title}", description: '', file: asset_file)
          asset_status(asset, asset_attributes)
        end
      end
    end

    def create_asset_file(asset_title, params)
      Contentful::Management::File.new.tap do |file|
        file.properties[:contentType] = file_content_type(params)
        file.properties[:fileName] = asset_title
        file.properties[:upload] = params['url']
      end
    end

    def asset_status(asset, asset_attributes)
      if asset.is_a?(Contentful::Management::Asset)
        puts "Process asset - #{asset.id} "
        asset.process_file
        CSV.open("#{config.success_logs_dir}/assets_log.csv", 'a') { |csv| csv << [asset.id] }
      else
        puts "Error - #{asset.message} "
        CSV.open("#{config.success_logs_dir}/assets_failure.csv", 'a') { |csv| csv << [asset_attributes['id']] }
      end
    end

    def publish_entries_in_threads
      threads =[]
      number_of_threads.times do |thread_id|
        threads << Thread.new do
          self.class.new(config).publish_all_entries("#{config.threads_dir}/#{thread_id}")
        end
      end
      threads.each do |thread|
        thread.join
      end
    end

    def publish_all_entries(thread_dir)
      create_log_file('log_published_entries')
      config.published_entries << CSV.read("#{config.success_logs_dir}/log_published_entries.csv", 'r').flatten
      Dir.glob("#{thread_dir}/*json") do |entry_file|
        entry_id = JSON.parse(File.read(entry_file))['id']
        publish_entry(entry_id) unless config.published_entries.flatten.include?(entry_id)
      end
    end

    def publish_entry(entry_id)
      puts "Publish entries for #{entry_id}."
      entry = Contentful::Management::Entry.find(config.config['space_id'], entry_id).publish
      publish_status(entry, entry_id)
    end

    private

    def initialize_space(space)
      fail 'You need to specify \'--space_id\' argument to find an existing Space or \'--space_name\' to create a new Space.' if space[:space_id].nil? && [:space_name].nil?
      @space = space[:space_id].present? ? Contentful::Management::Space.find(space[:space_id]) : create_space(space[:space_name])
    end

    def create_space(name_space)
      puts "Creating a space with name: #{name_space}"
      Contentful::Management::Space.create(name: name_space, organization_id: config.config['organization_id'])
    end

    def import_content_types
      Dir.glob("#{config.collections_dir}/*json") do |file_path|
        collection_attributes = JSON.parse(File.read(file_path))
        content_type = create_new_content_type(space, collection_attributes)
        puts "Importing content_type: #{content_type.name}"
        create_content_type_fields(collection_attributes, content_type)
        add_content_type_id_to_file(collection_attributes, content_type.id, content_type.space.id, file_path)
        content_type.update(displayField: collection_attributes['displayField']) if collection_attributes['displayField']
        active_status(content_type.activate)
      end
    end

    def get_space_id(collection)
      collection['space_id']
    end

    def get_id(params)
      File.basename(params['id'] || params['url'])
    end

    def create_content_type_fields(collection_attributes, content_type)
      fields = collection_attributes['fields'].each_with_object([]) do |field, fields|
        fields << create_field(field)
      end
      content_type.fields = fields
      content_type.save
    end

    def import_entry(file_path, space_id, content_type_id, log_file)
      entry_attributes = JSON.parse(File.read(file_path))
      puts "Creating entry: #{entry_attributes['id']}."
      entry_params = create_entry_parameters(content_type_id, entry_attributes, space_id)
      content_type = content_type(content_type_id, space_id)
      entry = content_type.entries.create(entry_params)
      import_status(entry, file_path, log_file)
    end

    def create_entry_parameters(content_type_id, entry_attributes, space_id)
      entry_attributes.each_with_object({}) do |(attr, value), entry_params|
        next if attr.start_with?('@')
        entry_param = if value.is_a? Hash
                        parse_attributes_from_hash(value, space_id, content_type_id)
                      elsif value.is_a? Array
                        parse_attributes_from_array(value, space_id, content_type_id)
                      else
                        value
                      end
        entry_params[attr.to_sym] = entry_param unless validate_param(entry_param)
      end
    end

    def parse_attributes_from_hash(params, space_id, content_type_id)
      type = params['type']
      if type
        case type
          when 'Location'
            create_location_file(params)
          when 'File'
            create_asset(space_id, params)
          else
            create_entry(params, space_id, content_type_id)
        end
      else
        params
      end
    end

    def parse_attributes_from_array(params, space_id, content_type_id)
      params.each_with_object([]) do |attr, array_attributes|
        value = if attr['type'].present? && attr['type'] != 'File'
                  create_entry(attr, space_id, content_type_id)
                elsif attr['type'] == 'File'
                  create_asset(space_id, attr)
                else
                  attr
                end
        array_attributes << value unless value.nil?
      end
    end

    def import_status(entry, file_path, log_file)
      if entry.is_a? Contentful::Management::Entry
        entry_file_name = File.basename(file_path)
        puts 'Imported successfully!'
        CSV.open("#{config.success_logs_dir}/#{log_file}.csv", 'a') { |csv| csv << [entry_file_name] }
      else
        puts "### Failure! - #{entry.message}  - #{entry.response.raw}###"
        CSV.open("#{config.failure_logs_dir}/fail_#{log_file}.csv", 'a') { |csv| csv << [file_path, entry.message, entry.response.raw] }
      end
    end

    def content_type(content_type_id, space_id)
      @content_type = APICache.get("content_type_#{content_type_id}", :period => -5) do
        Contentful::Management::ContentType.find(space_id, content_type_id)
      end
    end

    def add_content_type_id_to_file(collection, content_type_id, space_id, file_path)
      File.open(file_path, 'w') { |file| file.write(format_json(collection.merge(content_type_id: content_type_id, space_id: space_id))) }
    end

    def create_entry(params, space_id, content_type_id)
      entry_id = get_id(params)
      content_type = content_type(content_type_id, space_id)
      content_type.entries.new.tap do |entry|
        entry.id = entry_id
      end
    end

    def create_asset(space_id, params)
      if params['id']
        space = Contentful::Management::Space.find(space_id)
        found_asset = space.assets.find(params['id'])
        asset = found_asset.is_a?(Contentful::Management::Asset) ? found_asset : initialize_asset_file(params)
        asset
      end
    end

    def initialize_asset_file(params)
      Contentful::Management::Asset.new.tap do |asset|
        asset.id = params['id']
        asset.link_type = 'Asset'
      end
    end

    def create_location_file(params)
      Contentful::Management::Location.new.tap do |file|
        file.lat = params['lat']
        file.lon = params['lng']
      end
    end

    def create_field(field)
      field_params = {id: field['id'], name: field['name'], required: field['required']}
      field_params.merge!(additional_field_params(field))
      puts "Creating field: #{field_params[:type]}"
      create_content_type_field(field_params)
    end

    def create_content_type_field(field_params)
      Contentful::Management::Field.new.tap do |field|
        field.id = field_params[:id]
        field.name = field_params[:name]
        field.type = field_params[:type]
        field.link_type = field_params[:link_type]
        field.required = field_params[:required]
        field.items = field_params[:items]
      end
    end

    def active_status(ct_object)
      if ct_object.is_a? Contentful::Management::Error
        puts "### Failure! - #{ct_object.message} ! ###"
      else
        puts 'Successfully activated!'
      end
    end

    def publish_status(ct_object, entry_id)
      if ct_object.is_a? Contentful::Management::Error
        puts "### Failure! - #{ct_object.message} ! ###"
        CSV.open("#{config.success_logs_dir}/failure_published_entries.csv", 'a') { |csv| csv << [entry_id] }
      else
        puts 'Successfully activated!'
        CSV.open("#{config.success_logs_dir}/log_published_entries.csv", 'a') { |csv| csv << [ct_object.id] }
      end
    end

    def additional_field_params(field)
      field_type = field['type']
      if field_type == 'Entry' || field_type == 'Asset'
        {type: 'Link', link_type: field_type}
      elsif field_type == 'Array'
        {type: 'Array', items: create_array_field(field)}
      else
        {type: field_type}
      end
    end

    def validate_param(param)
      if param.is_a? Array
        param.empty?
      else
        param.nil?
      end
    end

    def create_new_content_type(space, collection_attributes)
      space.content_types.new.tap do |content_type|
        content_type.id = collection_attributes['id']
        content_type.name = collection_attributes['name']
        content_type.description = collection_attributes['description']
      end
    end

    def file_content_type(params)
      MimeContentType::EXTENSION_LIST[File.extname(params['url'])]
    end

    def format_json(item)
      JSON.pretty_generate(JSON.parse(item.to_json))
    end

    def create_array_field(params)
      Contentful::Management::Field.new.tap do |field|
        field.type = params['link'] || 'Link'
        field.link_type = params['link_type']
      end
    end

    def create_directory(path)
      FileUtils.mkdir_p(path) unless File.directory?(path)
    end

    def create_log_file(path)
      create_directory("#{config.data_dir}/logs")
      File.open("#{config.data_dir}/logs/#{path}.csv", 'a') { |file| file.write('') }
    end

    def load_log_files
      Dir.glob("#{config.success_logs_dir}/*.csv") do |log_files|
        file_name = File.basename(log_files)
        imported_ids = CSV.read(log_files, 'r').flatten
        config.imported_entries << imported_ids if file_name.start_with?('success_thread') && !config.imported_entries.include?(imported_ids)
      end
    end

  end
end

