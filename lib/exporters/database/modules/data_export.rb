module Contentful
  module Exporter
    module Database
      module DataExport

        def content_type_name(content_type)
          content_type.gsub(' ', '_').underscore
        end

        def create_directory(path)
          FileUtils.mkdir_p(path) unless File.directory?(path)
        end

        def create_content_type_json_file(content_type_name, values)
          collection = {
              id: values[:id],
              entry_type: content_type_name,
              note: values[:note],
              displayField: values[:displayField],
              fields: create_fields(values[:fields])
          }
          write_json_to_file("#{collections_dir}/#{content_type_name}.json", collection)
        end

        def create_fields(fields)
          fields.each_with_object([]) do |(field, value), results|
            results << {
                name: value.is_a?(Hash) ? value[:id] : field.capitalize,
                identifier: value.is_a?(Hash) ? value[:id] : field,
                input_type: value.is_a?(Hash) ? value[:link_type] : value,
                link_type: value.is_a?(Hash) ? value[:type] : nil
            }.compact
          end
        end

      end
    end
  end
end

