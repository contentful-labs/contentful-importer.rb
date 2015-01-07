require 'spec_helper'
require 'json_schema_validator'

module Contentful
  describe JsonSchemaValidator do

    include_context 'shared_configuration'

    it 'initialize' do
      validator = JsonSchemaValidator.new(@config)
      expect(validator.config).to be_a Contentful::Configuration
    end

    it 'validate_schemas' do
      expect_any_instance_of(Contentful::JsonSchemaValidator).to receive(:validate_schema).exactly(5).times
      JsonSchemaValidator.new(@config).validate_schemas
    end

    it 'validate_schema' do
      expect_any_instance_of(Contentful::JsonSchemaValidator).to receive(:validate_entry).with('comment',
                                                                                               {'type' => 'object',
                                                                                                'properties' => {'subject' => {'type' => 'string'},
                                                                                                                 'content' => {'type' => 'string'}
                                                                                                }})
      JsonSchemaValidator.new(@config).validate_schema('spec/fixtures/import_files/collections/comment.json')
    end

    it 'validate_entry' do
      schema = load_json('import_files/collections/comment')
      expect { JsonSchemaValidator.new(@config).validate_entry('comment', schema) }.not_to raise_error
    end

    it 'parse_content_type_schema' do
      ct_file = load_json('import_files/collections/comment')
      result = JsonSchemaValidator.new(@config).parse_content_type_schema(ct_file)
      expect(result).to include('type' => 'object', 'properties' => {'subject' => {'type' => 'string'}, 'content' => {'type' => 'string'}})
    end

    it 'base schema form' do
      result = JsonSchemaValidator.new(@config).base_schema_format
      expect(result).to include('type' => 'object', 'properties' => {})
    end

    context 'convert_type' do
      it 'Text to String' do
        result = JsonSchemaValidator.new(@config).convert_type('Text')
        expect(result).to eq 'string'
      end
      it 'Number to Float' do
        result = JsonSchemaValidator.new(@config).convert_type('Number')
        expect(result).to eq 'float'
      end
      it 'Asset to Object(Hash)' do
        result = JsonSchemaValidator.new(@config).convert_type('Asset')
        expect(result).to eq 'object'
      end
      it 'Other to downcase format' do
        result = JsonSchemaValidator.new(@config).convert_type('Integer')
        expect(result).to eq 'integer'
      end
    end

  end
end