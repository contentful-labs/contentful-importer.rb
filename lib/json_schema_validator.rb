require 'json-schema'

module Contentful
  class JsonSchemaValidator

    attr_reader :config, :logger

    def initialize(configuration)
      @config = configuration
      @logger = Logger.new(STDOUT)
    end

    def validate_schemas
      Dir.glob("#{config.collections_dir}/*") do |content_type_file|
        validate_schema(content_type_file)
      end
    end

    def validate_schema(content_type_file)
      schema = parse_content_type_schema(JSON.parse(File.read(content_type_file)))
      content_type_filename = File.basename(content_type_file, '.*')
      validate_entry(content_type_filename, schema)
    end

    def validate_entry(content_type_filename, schema)
      Dir.glob("#{config.entries_dir}/#{content_type_filename}/*") do |entry_file|
        entry_schema = JSON.parse(File.read(entry_file))
        begin
          JSON::Validator.validate!(schema, entry_schema)
        rescue JSON::Schema::ValidationError => error
          logger.info "#{error.message}! Path to invalid entry: #{entry_file}"
        end
      end
    end

    def parse_content_type_schema(ct_file)
      new_hash = base_schema_format
      ct_file['fields'].each do |key|
        type = convert_type(key['type'])
        new_hash['properties'].merge!({key['id'] => {'type' => type}})
      end
      new_hash
    end

    def base_schema_format
      {'type' => 'object', 'properties' => {}}
    end

    def convert_type(type)
      case type
        when 'Text', 'Date', 'Symbol'
          'string'
        when 'Number'
          'float'
        when 'Asset', 'Entry'
          'object'
        else
          type.downcase
      end
    end

  end
end

