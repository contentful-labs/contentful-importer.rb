module Contentful
  module Exporter
    module Database
      module JsonExport

        CHAR_MAP = {
            ' ' => '_',
            'ä' => 'a',
            'ü' => 'u',
            'ö' => 'o'
        }

        def asset?(model_name)
          config.mapping[model_name] && config.mapping[model_name][:type] == 'asset'
        end

        def save_object_to_file(table, content_type_name, model_name, type)
          content_type_name = content_type_name.underscore.gsub(/[\säüö]+/) { |match| CHAR_MAP[match] }
          create_directory("#{type}/#{content_type_name}")
          config.db[table].all.each_with_index do |row, index|
            result = transform_row_into_hash(model_name, content_type_name, row, index)
            write_json_to_file("#{type}/#{content_type_name}/#{result[:id]}.json", result)
          end
        end

        def transform_row_into_hash(model_name, content_type_name, row, index)
          id = row[:id] || index
          puts "Saving #{content_type_name} - id: #{id}"
          db_object = map_fields(model_name, row)
          db_object[:id] = model_id(model_name, content_type_name, id)
          db_object[:database_id] = id
          db_object[:import_id] = id.to_s #TODO REMOVE AFTER RECIPES IMPORT
          db_object
        end

        def model_id(model_name, content_type_name, id)
          prefix = config.mapping[model_name][:prefix_id] || ''
          prefix + "#{content_type_name}_#{id}"
        end

        def map_fields(model_name, row)
          row.each_with_object({}) do |(field_name, field_value), result|
            field_name = mapped_field_name(field_name, model_name)
            formatted_value = formatted_field_value(field_name, field_value, model_name)
            result[field_name] = formatted_value
            copy_field_value(field_name, formatted_value, model_name, result) if copy_field?(field_name, model_name)
          end
        end

        def formatted_field_value(field_name, field_value, model_name)
          has_mapping_value?(field_name, model_name) ? format_value(field_name, field_value, model_name) : field_value
        end

        def copy_field_value(field_name, field_value, model_name, result)
          copy_field = config.mapping[model_name][:copy][field_name]
          result[copy_field] = format_value(copy_field, field_value, model_name)
        end

        def format_value(field_name, field_value, model_name)
          char_map = config.mapping[model_name][:format][field_name]
          field_value.underscore.gsub(/[\säüö]+/) { |match| char_map[match] }
        end

        def mapped_field_name(field_name, model_name)
          has_mapping_for?(field_name, model_name) ? config.mapping[model_name][:fields][field_name] : field_name
        end

        def has_mapping_for?(field_name, model_name)
          config.mapping[model_name] && config.mapping[model_name][:fields][field_name].present?
        end

        def has_mapping_value?(field_name, model_name)
          config.mapping[model_name] && config.mapping[model_name][:format] && config.mapping[model_name][:format][field_name].present?
        end

        def copy_field?(field_name, model_name)
          config.mapping[model_name] && config.mapping[model_name][:copy] && config.mapping[model_name][:copy][field_name].present?
        end

      end
    end
  end
end

