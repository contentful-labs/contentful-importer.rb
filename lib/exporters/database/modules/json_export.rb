module Contentful
  module Exporter
    module Database
      module JsonExport

        def asset?(model_name)
          mapping[model_name] && mapping[model_name][:type] == :asset
        end

        def save_object_to_file(table, content_type_name, model_name, type)
          create_directory("#{type}/#{content_type_name}")
          db[table].all.each_with_index do |row, index|
            result = transform_row_into_hash(model_name, content_type_name, row, index)
            write_json_to_file("#{type}/#{content_type_name}/#{result[:id]}.json", result)
          end
        end

        def transform_row_into_hash(model_name, content_type_name, row, index)
          id = row[:id] || index
          puts "Saving #{content_type_name} - id: #{id}"
          db_object = map_fields(model_name, row)
          db_object[:id] ="#{content_type_name}_#{id}"
          db_object[:database_id] = id
          db_object
        end

        def map_fields(model_name, row)
          row.each_with_object({}) do |(field_name, field_value), result|
            field_name = mapped_field_name(field_name, model_name)
            result[field_name] = field_value
          end
        end

        def mapped_field_name(field_name, model_name)
          has_mapping_for?(field_name, model_name) ? mapping[model_name][:fields][field_name] : field_name
        end

        def has_mapping_for?(field_name, model_name)
          mapping[model_name] && mapping[model_name][:fields][field_name].present?
        end

      end
    end
  end
end

