require_relative 'mime_content_type'
require 'contentful/management'
require 'csv'
require 'yaml'
require 'api_cache'

module Contentful
  class ParallelImporter

    attr_reader :space,
                :config
    attr_accessor :content_type

    def initialize(settings)
      @config = settings
      Contentful::Management::Client.new(config.config['access_token'])
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


    def import_in_threads
      threads_count = Dir.glob("#{config.threads_dir}/*").count
      threads = []
      threads_count.times do |thread_id|
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
      config.imported_entries << CSV.read("#{config.success_logs_dir}/#{log_file_name}.csv", 'r').flatten
      Dir.glob("#{path}/*.json") do |entry_path|
        content_type_id = File.basename(entry_path).match(/(\D+[a-zA-Z])/)[0]
        import_entry(entry_path, space_id, content_type_id, log_file_name) unless config.imported_entries.flatten.include?(entry_path)
      end
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

    def publish_all_entries
      Dir.glob("#{config.collections_dir}/*json") do |dir_path|
        collection_name = File.basename(dir_path, '.json')
        puts "Publish entries for #{collection_name}."
        collection_attributes = JSON.parse(File.read("#{config.collections_dir}/#{collection_name}.json"))
        Contentful::Management::Space.find(get_space_id(collection_attributes)).entries.all.each do |entry|
          puts "Publish an entry with ID #{entry.id}."
          active_status(entry.publish)
        end
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
      entry_id = File.basename(file_path, '.json')
      puts "Creating entry: #{entry_id}."
      entry_params = create_entry_parameters(content_type_id, entry_attributes, space_id)
      content_type = content_type(content_type_id, space_id)
      entry = content_type.entries.create(entry_params.merge(id: entry_id))
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
        value = if attr['type']
                  create_entry(attr, space_id, content_type_id)
                else
                  attr
                end
        array_attributes << value unless value.nil?
      end
    end

    def import_status(entry, file_path, log_file)
      if entry.is_a? Contentful::Management::Entry
        puts 'Imported successfully!'
        CSV.open("#{config.success_logs_dir}/#{log_file}.csv", 'a') { |csv| csv << [file_path] }
      else
        puts "### Failure! - #{entry.message}  - #{entry.response.raw}###"
        CSV.open("#{config.failure_logs_dir}/fail_#{log_file}.csv", 'a') { |csv| csv << [file_path, entry.message, entry.response.raw] }
      end
    end

    def content_type(content_type_id, space_id)
      @content_type = APICache.get("content_type_#{content_type_id}") do
        Contentful::Management::ContentType.find(space_id, content_type_id)
      end
    end

    def add_content_type_id_to_file(collection, content_type_id, space_id, file_path)
      File.open(file_path, 'w') { |file| file.write(format_json(collection.merge(content_type_id: content_type_id, space_id: space_id))) }
    end

    def create_entry(params, space_id, content_type_id)
      entry_id = get_id(params)
      content_type = content_type(content_type_id,space_id)
      content_type.entries.new.tap do |entry|
        entry.id = entry_id
      end
    end

    def create_asset(space_id, params)
      asset_file = Contentful::Management::File.new.tap do |file|
        file.properties[:contentType] = file_content_type(params)
        file.properties[:fileName] = params['type']
        file.properties[:upload] = params['id']
      end
      space = Contentful::Management::Space.find(space_id)
      space.assets.create(title: "#{params['type']}", description: '', file: asset_file).process_file
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
      MimeContentType::EXTENSION_LIST[File.extname(params['id'])]
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

  end
end

