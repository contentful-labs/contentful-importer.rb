module Contentful
  module Exporter
    module Database
      module RelationsExport

        def generate_relations_helper_indexes(relations)
          create_directory(helpers_dir)
          relations.each do |relation_type, linked_models|
            save_relation_foreign_keys(relation_type, linked_models) if [:many, :many_through, :aggregate_many, :aggregate_through].include?(relation_type.to_sym)
          end
        end

        def save_relation_foreign_keys(relation_type, linked_models)
          linked_models.each do |linked_model|
            save_relation_foreign_keys_for_model(linked_model, relation_type)
          end
        end

        def save_relation_foreign_keys_for_model(linked_model, relation_type)
          primary_id = linked_model[:primary_id]
          case relation_type.to_sym
            when :many_through, :aggregate_through
              related_model = linked_model[:through]
              related_model_id = linked_model[:foreign_id]
            when :many, :aggregate_many
              related_model = linked_model[:relation_to]
              related_model_id = :id
          end
          save_foreign_keys(related_model, primary_id, related_model_id)
        end

        def save_foreign_keys(related_model, primary_id, related_model_id)
          results = db[related_model.underscore.to_sym].all.each_with_object({}) do |row, results|
            add_index_to_helper_hash(results, row, primary_id, related_model_id)
          end
          write_json_to_file(helpers_dir + "/#{primary_id}_#{related_model.underscore}.json", results)
        end

        def add_index_to_helper_hash(results, row, primary_id, id)
          results[row[primary_id]].nil? ? results[row[primary_id]] = [row[id]] : results[row[primary_id]] << row[id]
        end

        def map_relations_to_links(model_name, relations)
          records = 0
          Dir.glob("#{entries_dir}/#{model_content_type(model_name).underscore}/*json") do |entry_path|
            map_entry_relations(entry_path, model_name, relations, records)
            records += 1
          end
        end

        def relations_from_mapping
          mapping.each_with_object({}) do |(model_name, model_mapping), relations|
            relations[model_name] = model_mapping[:links] if model_mapping[:links].present?
          end
        end

        def map_entry_relations(entry_path, model_name, relations, record)
          relations.each do |relation_type, linked_models|
            puts "Mapping #{model_name} - relation: #{relation_type} - #{linked_models}, record: #{record}" if record % 1000 == 0
            map_entry_relation(entry_path, relation_type, linked_models, model_name)
          end
        end

        def map_entry_relation(entry_path, relation_type, linked_models, model_name)
          entry = JSON.parse(File.read(entry_path))
          linked_models.each do |linked_model|
            relationships(entry, entry_path, relation_type, model_name, linked_model)
          end
        end

        def relationships(entry, entry_path, relation_type, model_name, linked_model)
          case relation_type.to_sym
            when :has_one
              # map_has_one_association(model_name, linked_model, row)
            when :belongs_to
              map_belongs_to_association(model_name, linked_model, entry, entry_path)
            when :many_through
              map_many_association(model_name, linked_model, entry, entry_path, :through)
            when :many
              map_many_association(model_name, linked_model, entry, entry_path, :relation_to)
            when :aggregate_through
              aggregate_data(model_name, linked_model, entry, entry_path, :through)
            when :aggregate_many
              aggregate_data(model_name, linked_model, entry, entry_path, :relation_to)
          end
        end

        def model_content_type(model_name)
          mapping[model_name][:content_type]
        end

        def map_belongs_to_association(model_name, linked_model, entry, entry_path)
          ct_link_type = contentful_field_attribute(model_name, linked_model, :link_type)
          ct_field_id = contentful_field_attribute(model_name, linked_model, :id)
          save_belongs_to_entries(linked_model, ct_link_type, ct_field_id, entry, entry_path)
        end

        def contentful_field_attribute(model_name, associated_model, type)
          contentful_structure[model_content_type(model_name)][:fields][model_content_type(associated_model)][type]
        end

        def save_belongs_to_entries(linked_model, ct_link_type, ct_field_id, entry, entry_path)
          content_type = model_content_type(linked_model).underscore
          foreign_id = content_type + '_id'
          if entry[foreign_id].present?
            case ct_link_type
              when 'Asset'
                type = 'File'
                cf_object = 'asset_id'
              when 'Entry'
                type = 'Entry'
                cf_object = 'id'
            end
            object = {
                'type' => type,
                cf_object => "#{content_type}_#{entry[foreign_id]}"
            }
            write_json_to_file(entry_path, entry.merge!(ct_field_id => object))
          end
        end

        def save_many_entries(linked_model, ct_field_id, entry, entry_path, related_to)
          related_model = linked_model[related_to].underscore
          contentful_name = model_content_type(linked_model[:relation_to]).underscore
          associated_objects = add_associated_object_to_file(entry, related_model, contentful_name, linked_model[:primary_id])
          write_json_to_file(entry_path, entry.merge!(ct_field_id => associated_objects)) if associated_objects.present?
        end

        def map_many_association(model_name, linked_model, entry, entry_path, related_to)
          ct_field_id = contentful_field_attribute(model_name, linked_model[:relation_to], :id)
          save_many_entries(linked_model, ct_field_id, entry, entry_path, related_to)
        end

        def add_associated_object_to_file(entry, related_model, contentful_name, primary_id)
          Dir.glob("#{helpers_dir}/#{primary_id}_#{related_model}.json") do |through_file|
            hash_with_foreign_keys = JSON.parse(File.read(through_file))
            return build_hash_with_associated_objects(hash_with_foreign_keys, entry, contentful_name)
          end
        end

        def build_hash_with_associated_objects(hash_with_foreign_keys, entry, contentful_name)
          if hash_with_foreign_keys.has_key?(entry['database_id'].to_s)
            associated_objects = hash_with_foreign_keys[entry['database_id'].to_s].each_with_object([]) do |foreign_key, result|
              result << {
                  'type' => contentful_name,
                  'id' => "#{contentful_name}_#{foreign_key}"
              }
            end
          end
          associated_objects
        end


        ########################################################
        def aggregate_data(model_name, linked_model, entry, entry_path, related_to)
          ct_field_id = contentful_field_attribute(model_name, linked_model[:relation_to], :id)
          save_aggregated_entries(linked_model, ct_field_id, entry, entry_path, related_to)
        end

        def save_aggregated_entries(linked_model, ct_field_id, entry, entry_path, related_to)
          related_model = linked_model[related_to].underscore
          contentful_name = model_content_type(linked_model[:relation_to]).underscore
          associated_objects = save_aggregated_object_to_file(entry, related_model, contentful_name, linked_model)
          write_json_to_file(entry_path, entry.merge!(ct_field_id => associated_objects)) if associated_objects.present?
        end

        def save_aggregated_object_to_file(entry, related_model, contentful_name, linked_model)
          primary_id = linked_model[:primary_id]
          Dir.glob("#{helpers_dir}/#{primary_id}_#{related_model}.json") do |through_file|
            hash_with_foreign_keys = JSON.parse(File.read(through_file))
            return hash_with_aggregate_objects(hash_with_foreign_keys, entry, contentful_name, linked_model)
          end
        end

        def hash_with_aggregate_objects(hash_with_foreign_keys, entry, contentful_name, linked_model)
          if hash_with_foreign_keys.has_key?(entry['database_id'].to_s)
            associated_objects = hash_with_foreign_keys[entry['database_id'].to_s].each_with_object([]) do |foreign_key, result|
              aggregated_file = JSON.parse(File.read("#{entries_dir}/#{contentful_name}/#{contentful_name}_#{foreign_key}.json"))
              result << aggregated_file[linked_model[:field]]
            end
          end
          associated_objects
        end

        ########################################################

        # def map_has_one_association(linked_model, model_name, row)
        #   associated_model = linked_model.underscore
        #   foreign_key = associated_model + '_id'
        #   id = row[foreign_key]
        #   associated_content_type = mapping[linked_model][:content_type]
        #   link_type = contentful_field_attribute(associated_content_type, model_name, :link_type)
        #   api_field_id = contentful_field_attribute(associated_content_type, model_name, :id)
        #   if id
        #     file_to_modify = JSON.parse(File.read("#{entries_dir}/#{associated_model}/#{associated_model}_#{id}.json"))
        #     case link_type
        #       when 'Array'
        #         File.open("#{entries_dir}/#{associated_model}/#{associated_model}_#{id}.json", 'w') do |file|
        #           array = file_to_modify[api_field_id].nil? ? [] : file_to_modify[api_field_id]
        #           array << {
        #               'type' => model_name,
        #               'id' => row['id']
        #           }
        #           file.write((JSON.pretty_generate(file_to_modify.merge!(api_field_id => array))))
        #         end
        #       when 'Entry'
        #         puts 'NOT IMPLEMENTED YET - map_has_one_association'
        #       when 'Asset'
        #         puts 'NOT IMPLEMENTED YET - map_has_one_association'
        #     end
        #   end
        # end

      end
    end
  end
end

