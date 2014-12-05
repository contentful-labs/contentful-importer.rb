require 'i18n'

module Contentful
  module Exporter
    module Database
      module JsonExport

        def asset?(model_name)
          mapping[model_name] && mapping[model_name][:type] == 'asset'
        end

        def save_object_to_file(table, content_type_name, model_name, type)
          content_type_name = I18n.transliterate(content_type_name).underscore.tr(' ','_')
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
          db_object
        end

        def model_id(model_name, content_type_name, id)
          prefix = mapping[model_name][:prefix_id] || ''
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
          has_mapping_value?(field_name, model_name) ? format_value(field_value) : field_value
        end

        def copy_field_value(field_name, field_value, model_name, result)
          copy_field = mapping[model_name][:copy][field_name]
          result[copy_field] = format_value(field_value.to_s)
        end

        def format_value(field_value)
          formatted_value = I18n.transliterate(field_value).tr(' ','_').underscore
          formatted_value.underscore.gsub(/\W/, '-').gsub(/\W\z/, '').gsub(/\A\W/, '').gsub('_', '-').gsub('--', '-').gsub('--', '-')
        end

        def mapped_field_name(field_name, model_name)
          has_mapping_for?(field_name, model_name) ? mapping[model_name][:fields][field_name] : field_name
        end

        def has_mapping_for?(field_name, model_name)
          mapping[model_name] && mapping[model_name][:fields][field_name].present?
        end

        def has_mapping_value?(field_name, model_name)
          mapping[model_name] && mapping[model_name][:format] && mapping[model_name][:format][field_name].present?
        end

        def copy_field?(field_name, model_name)
          mapping[model_name] && mapping[model_name][:copy] && mapping[model_name][:copy][field_name].present?
        end

      end
    end
  end
end

