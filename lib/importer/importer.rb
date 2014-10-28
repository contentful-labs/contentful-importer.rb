require_relative 'mime_content_type'
require 'contentful/management'
require 'csv'
require 'yaml'

module Contentful
  class Importer

    attr_reader :space,
                :config,
                :data_dir,
                :collections_dir,
                :entries_dir,
                :assets_dir,
                :time_logs_dir,
                :success_logs_dir,
                :failure_logs_dir,
                :imported_entries

    def initialize
      @config = SETTINGS
      @data_dir = config['data_dir']
      @collections_dir = "#{data_dir}/collections"
      @entries_dir = "#{data_dir}/entries"
      @assets_dir = "#{data_dir}/assets"
      @time_logs_dir = "#{data_dir}/logs/time.json"
      @success_logs_dir = "#{data_dir}/logs/success.json"
      @failure_logs_dir = "#{data_dir}/logs/failure.json"
      @imported_entries = []

      Contentful::Management::Client.new(config['access_token'])
    end

    def execute
      create_space
      import_content_types
      import_entries
    end

    def test_credentials
      space = Contentful::Management::Space.all
      if space.is_a? Contentful::Management::Array
        puts 'Contentful Management API credentials: OK'
      end
    rescue NoMethodError => _error
      puts 'Contentful Management API credentials: INVALID (check README)'
    end

    private

    def create_space
      puts 'Name for a new created space on Contentful:'
      name_space = gets.strip
      @space = Contentful::Management::Space.create(name: name_space, organization_id: config['organization_id'])
    end

    def import_content_types
      Dir.glob("#{collections_dir}/*json") do |file_path|
        collection_attributes = JSON.parse(File.read(file_path))
        content_type = space.content_types.create(name: collection_attributes['entry_type'], description: collection_attributes['note'])
        puts "Importing content_type: #{content_type.name}"
        create_content_type_fields(collection_attributes, content_type)
        add_content_type_id_to_file(collection_attributes, content_type.id, content_type.space.id, file_path)
        content_type.update(displayField: collection_attributes['displayField']) if collection_attributes['displayField']
        active_status(content_type.activate)
      end
    end

    def import_entries
      create_file_with_import_time
      create_log_file
      imported_entries << CSV.read(success_logs_dir, 'r').flatten
      Dir.glob("#{entries_dir}/*") do |dir_path|
        collection_name = File.basename(dir_path)
        puts "Importing entries for #{collection_name}."
        collection_attributes = JSON.parse(File.read("#{collections_dir}/#{collection_name}.json"))
        content_type_id = collection_attributes['content_type_id']
        space_id = collection_attributes['space_id']
        import_entries_for_collection(content_type_id, dir_path, space_id)
      end
    end

    def publish_all_entries
      Dir.glob("#{collections_dir}/*json") do |dir_path|
        collection_name = File.basename(dir_path, '.json')
        puts "Publish entries for #{collection_name}."
        collection_attributes = JSON.parse(File.read("#{collections_dir}/#{collection_name}.json"))
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
      collection_attributes['fields'].each do |field|
        create_field(field, content_type)
      end
    end

    def import_entries_for_collection(content_type_id, dir_path, space_id)
      puts "Start mapping at: #{start = Time.now}"; records = 0
      Dir.glob("#{dir_path}/*.json") do |file_path|
        import_entry(file_path, space_id, content_type_id) unless imported_entries.flatten.include?(file_path)
        records += 1
      end
      import_time = JSON.parse(File.read("#{time_logs_dir}"))
      File.open(time_logs_dir, 'w') { |file| file.write(JSON.pretty_generate(import_time.merge(dir_path => {total_time: "#{((Time.now - start)/60).round(2)} min.", records_mapped: "#{records}"}))) }
    end

    def import_entry(file_path, space_id, content_type_id)
      entry_attributes = JSON.parse(File.read(file_path))
      entry_id = File.basename(file_path, '.json')
      puts "Creating entry: #{entry_id}."
      entry_params = create_entry_parameters(content_type_id, entry_attributes, space_id)
      entry = content_type(content_type_id, space_id).entries.create(entry_params.merge(id: entry_id))
      import_status(entry, file_path)
    rescue StandardError => error
      CSV.open(failure_logs_dir, 'a') { |csv| csv << [file_path, error.message] }
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

    def import_status(entry, file_path)
      if entry.is_a? Contentful::Management::Entry
        puts 'Imported successfully!'
        CSV.open(success_logs_dir, 'a') { |csv| csv << [file_path] }
      else
        puts "### Failure! - #{entry.message} ###"
        CSV.open(failure_logs_dir, 'a') { |csv| csv << [file_path, entry.message] }
      end
    end

    def content_type(content_type_id, space_id)
      Contentful::Management::ContentType.find(space_id, content_type_id)
    end

    def add_content_type_id_to_file(collection, content_type_id, space_id, file_path)
      File.open(file_path, 'w') { |file| file.write(format_json(collection.merge(content_type_id: content_type_id, space_id: space_id))) }
    end

    def create_entry(params, space_id, content_type_id)
      entry_id = get_id(params)
      content_type = Contentful::Management::ContentType.find(space_id, content_type_id)
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

    def create_field(field, content_type)
      field_params = {id: field['identifier'], name: field['name'], required: field['required']}
      field_params.merge!(additional_field_params(field))
      puts "Creating field: #{field_params[:type]}"
      content_type.fields.create(field_params)
    end

    def active_status(ct_object)
      if ct_object.is_a? Contentful::Management::Error
        puts "### Failure! - #{ct_object.message} ! ###"
      else
        puts 'Successfully activated!'
      end
    end

    def additional_field_params(field)
      field_type = field['input_type']
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

    def create_file_with_import_time
      create_directory("#{data_dir}/logs")
      File.open(time_logs_dir, 'w') { |file| file.write({}) }
    end

    def create_log_file
      CSV.open(success_logs_dir, 'a')
    end

  end
end

