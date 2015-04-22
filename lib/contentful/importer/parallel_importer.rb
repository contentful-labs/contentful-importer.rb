require_relative 'mime_content_type'
require_relative 'data_organizer'
require 'contentful/management'
require 'csv'
require 'yaml'
require 'api_cache'

module Contentful
  class ParallelImporter

    Encoding.default_external = 'utf-8'

    attr_reader :space, :config, :logger, :data_organizer
    attr_accessor :content_type

    def initialize(settings)
      @config = settings
      @logger = Logger.new(STDOUT)
      @data_organizer = Contentful::DataOrganizer.new(@config)
      Contentful::Management::Client.new(config.config['access_token'], default_locale: config.config['default_locale'] || 'en-US')
    end

    def create_contentful_model(space)
      initialize_space(space)
      import_content_types
    end

    def import_data(threads)
      clean_threads_dir_before_import(threads)
      data_organizer.execute(threads)
      import_in_threads
    end

    def test_credentials
      spaces = Contentful::Management::Space.all
      if spaces.is_a? Contentful::Management::Array
        logger.info 'Contentful Management API credentials: OK'
      end
    rescue NoMethodError => _error
      logger.info 'Contentful Management API credentials: INVALID (check README)'
    end

    def number_of_threads
      number_of_threads = 0
      Dir.glob("#{config.threads_dir}/*") do |thread|
        number_of_threads += 1 if File.basename(thread).size == 1
      end
      number_of_threads
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
      create_log_file('success_assets')
      assets_ids = Set.new(CSV.read("#{config.data_dir}/logs/success_assets.csv", 'r'))
      Dir.glob("#{config.assets_dir}/**/*json") do |file_path|
        asset_attributes = JSON.parse(File.read(file_path))
        if asset_url_param_start_with_http?(asset_attributes) && asset_not_imported_yet?(asset_attributes, assets_ids)
          import_asset(asset_attributes)
        end
      end
    end

    def import_asset(asset_attributes)
      logger.info "Import asset - #{asset_attributes['id']} "
      asset_title = asset_attributes['name'].present? ? asset_attributes['name'] : asset_attributes['id']
      asset_description = asset_attributes['description'].present? ? asset_attributes['description'] : ''
      asset_file = create_asset_file(asset_title, asset_attributes)
      space = Contentful::Management::Space.find(config.config['space_id'])
      asset = space.assets.create(id: "#{asset_attributes['id']}", title: "#{asset_title}", description: asset_description, file: asset_file)
      asset_status(asset, asset_attributes)
    end

    def asset_url_param_start_with_http?(asset_attributes)
      asset_attributes['url'] && asset_attributes['url'].start_with?('http')
    end

    def asset_not_imported_yet?(asset_attributes, assets_ids)
      !assets_ids.to_a.flatten.include?(asset_attributes['id'])
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
        logger.info "Process asset - #{asset.id} "
        asset.process_file
        CSV.open("#{config.log_files_dir}/success_assets.csv", 'a') { |csv| csv << [asset.id] }
      else
        logger.info "Error - #{asset.message} "
        CSV.open("#{config.log_files_dir}/failure_assets.csv", 'a') { |csv| csv << [asset_attributes['id']] }
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

    def publish_assets_in_threads(number_of_threads)
      clean_assets_threads_dir_before_publish(number_of_threads)
      data_organizer.split_assets_to_threads(number_of_threads)
      threads =[]
      number_of_threads.times do |thread_id|
        threads << Thread.new do
          self.class.new(config).publish_assets("#{config.threads_dir}/assets/#{thread_id}")
        end
      end
      threads.each do |thread|
        thread.join
      end
    end

    def publish_assets(thread_dir)
      create_log_file('success_published_assets')
      config.published_assets << CSV.read("#{config.log_files_dir}/success_published_assets.csv", 'r').flatten
      Dir.glob("#{thread_dir}/*json") do |asset_file|
        asset_id = JSON.parse(File.read(asset_file))['id']
        publish_asset(asset_id) unless config.published_assets.flatten.include?(asset_id)
      end
    end

    def publish_asset(asset_id)
      logger.info "Publish an Asset - ID: #{asset_id}"
      asset = Contentful::Management::Asset.find(config.config['space_id'], asset_id).publish
      publish_status(asset, asset_id, 'published_assets')
    end

    def publish_all_entries(thread_dir)
      create_log_file('success_published_entries')
      config.published_entries << CSV.read("#{config.log_files_dir}/success_published_entries.csv", 'r').flatten
      Dir.glob("#{thread_dir}/*json") do |entry_file|
        entry_id = JSON.parse(File.read(entry_file))['id']
        publish_entry(entry_id) unless config.published_entries.flatten.include?(entry_id)
      end
    end

    def publish_entry(entry_id)
      logger.info "Publish entries for #{entry_id}."
      entry = Contentful::Management::Entry.find(config.config['space_id'], entry_id).publish
      publish_status(entry, entry_id, 'published_entries')
    end

    private

    def initialize_space(space)
      fail 'You need to specify \'--space_id\' argument to find an existing Space or \'--space_name\' to create a new Space.' if space[:space_id].nil? && [:space_name].nil?
      @space = space[:space_id].present? ? Contentful::Management::Space.find(space[:space_id]) : create_space(space[:space_name])
    end

    def create_space(name_space)
      logger.info "Creating a space with name: #{name_space}"
      new_space = Contentful::Management::Space.create(name: name_space, organization_id: config.config['organization_id'])
      logger.info "Space was created successfully! Space id: #{new_space.id}"
      new_space
    end

    def import_content_types
      Dir.glob("#{config.collections_dir}/*json") do |file_path|
        collection_attributes = JSON.parse(File.read(file_path))
        content_type = create_new_content_type(space, collection_attributes)
        logger.info "Importing content_type: #{content_type.name}"
        create_content_type_fields(collection_attributes, content_type)
        content_type.update(displayField: collection_attributes['displayField']) if collection_attributes['displayField']
        active_status(content_type.activate)
      end
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
      logger.info "Creating entry: #{entry_attributes['id']}."
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
        logger.info 'Imported successfully!'
        CSV.open("#{config.log_files_dir}/#{log_file}.csv", 'a') { |csv| csv << [entry_file_name] }
      else
        logger.info "### Failure! - #{entry.message}  - #{entry.response.raw}###"
        failure_filename = log_file.match(/(thread_\d)/)[1]
        CSV.open("#{config.log_files_dir}/failure_#{failure_filename}.csv", 'a') { |csv| csv << [file_path, entry.message, entry.response.raw] }
      end
    end

    def content_type(content_type_id, space_id)
      @content_type = APICache.get("content_type_#{content_type_id}", :period => -5) do
        Contentful::Management::ContentType.find(space_id, content_type_id)
      end
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
      logger.info "Creating field: #{field_params[:type]}"
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
        logger.info "### Failure! - #{ct_object.message} ! ###"
      else
        logger.info 'Successfully activated!'
      end
    end

    def publish_status(ct_object, object_id, log_file_name)
      if ct_object.is_a? Contentful::Management::Error
        logger.info "### Failure! - #{ct_object.message} ! ###"
        CSV.open("#{config.log_files_dir}/failure_#{log_file_name}.csv", 'a') { |csv| csv << [object_id] }
      else
        logger.info 'Successfully activated!'
        CSV.open("#{config.log_files_dir}/success_#{log_file_name}.csv", 'a') { |csv| csv << [ct_object.id] }
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
      params['contentType'].present? ? params['contentType'] : MimeContentType::EXTENSION_LIST[File.extname(params['url'])]
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

    def clean_threads_dir_before_import(threads)
      threads.times do |thread|
        if File.directory?("#{config.threads_dir}/#{thread}")
          logger.info "Remove directory threads/#{thread} from #{config.threads_dir} path."
          FileUtils.rm_r("#{config.threads_dir}/#{thread}")
        end
      end
    end

    def clean_assets_threads_dir_before_publish(threads)
      threads.times do |thread|
        if File.directory?("#{config.threads_dir}/assets/#{thread}")
          logger.info "Remove directory threads/#{thread} from #{config.threads_dir}/assets path."
          FileUtils.rm_r("#{config.threads_dir}/assets/#{thread}")
        end
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
      Dir.glob("#{config.log_files_dir}/*.csv") do |log_files|
        file_name = File.basename(log_files)
        imported_ids = CSV.read(log_files, 'r').flatten
        config.imported_entries << imported_ids if file_name.start_with?('success_thread') && !config.imported_entries.include?(imported_ids)
      end
    end

  end
end
