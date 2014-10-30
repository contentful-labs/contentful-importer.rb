module Contentful
  class Converter

    attr_reader :config, :content_types, :import_form_dir

    def initialize(settings)
      @config = settings
      @import_form_dir = config['import_form_dir']
      @content_types = config['json_with_content_types']
    end

    def convert_to_import_form
      File.open(import_form_dir, 'w') { |file| file.write({}) }
      contentful_file = JSON.parse(File.read(content_types))['items']
      contentful_file.each do |content_type|
        parsed_content_type = {
            id: content_type['sys']['id'],
            note: content_type['description'],
            displayField: content_type['displayField'],
            fields: {}.merge!(create_fields(content_type))
        }
        import_form = JSON.parse(File.read(import_form_dir))
        File.open(import_form_dir, 'w') { |file| file.write(JSON.pretty_generate(import_form.merge!(content_type['name'] => parsed_content_type))) }
      end
    end

    def create_fields(content_type)
      content_type['fields'].each_with_object({}) do |(field, _value), results|
        id = link_id(field)
        results[id] = case field['type']
                        when 'Link'
                          {id: field['id'], link_type: field['linkType']}
                        when 'Array'
                          {id: field['id'], link_type: field['type'], type: field['items']['linkType'] || field['items']['type']}
                        else
                          field['type']
                      end
      end
    end

    def link_id(field)
      if %w( Link Array ).include? field['type']
        field['name']
      else
        field['id']
      end
    end
  end
end
