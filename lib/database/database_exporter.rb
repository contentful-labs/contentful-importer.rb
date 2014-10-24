require 'active_support/core_ext/string'
require 'active_support/core_ext/hash/compact'
require 'active_support/core_ext/hash'
require 'fileutils'
require_relative 'contentful_structure'
require_relative 'contentful_mapping'
require_relative 'aggregate_structure'
module Database
  class Exporter

    include ContentfulStructure
    include ContentfulMapping

    Sequel::Model.plugin :json_serializer

    #TODO MOVE TO SEPARATE FILE
    TABLES = [:user_wildeisen_alergic_info,
              :user_wildeisen_ingredient,
              :user_wildeisen_recipe,
              :user_wildeisen_recipe_to_alergic_info,
              :user_wildeisen_recipe_to_ingredient,
              :user_wildeisen_unit]

    attr_reader :contentful_structure, :mapping, :aggregate

    def initialize
      @contentful_structure = ContentfulStructure::STRUCTURE.with_indifferent_access
      @mapping = ContentfulMapping::MAPPING.with_indifferent_access
      @aggregate = AggregateStructure::AGGREGATE.with_indifferent_access
    end

    #######################################################################

    def export_models_from_database
      contentful_structure.each do |content_type, values|
        content_type_name = content_type_name(content_type)
        create_directory(COLLECTIONS_DATA_DIR)
        create_content_type_json_file(content_type_name, values)
      end
    end

    def content_type_name(content_type)
      content_type.gsub(' ', '_').underscore
    end

    def create_directory(path)
      FileUtils.mkdir_p(path) unless File.directory?(path)
    end

    def create_file_with_import_time
      File.open(IMPORT_TIME_DIR, 'w') { |file| file.write({}) }
    end

    def create_content_type_json_file(content_type_name, values)
      collection = {
          id: values[:id],
          entry_type: content_type_name,
          note: values[:note],
          displayField: values[:displayField],
          fields: create_fields(values[:fields])
      }
      write_json_to_file("#{COLLECTIONS_DATA_DIR}/#{content_type_name}.json", collection)
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

    #######################################################################

    def save_objects_as_json
      TABLES.each do |table|
        model_name = table.to_s.camelize
        content_type_name = mapping[model_name][:content_type].underscore
        save_object_to_file(table, content_type_name, model_name, asset?(model_name) ? ASSETS_DATA_DIR : ENTRIES_DATA_DIR)
      end
    end

    def asset?(model_name)
      mapping[model_name] && mapping[model_name][:type] == :asset
    end

    def save_object_to_file(table, content_type_name, model_name, type)
      create_directory("#{type}/#{content_type_name}")
      DB[table].all.each_with_index do |row, index|
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

    #######################################################################

    def create_contentful_links
      create_file_with_import_time
      relations_from_mapping.each do |model_name, relations|
        generate_relations_helper_indexes(relations)
        map_relations_to_links(model_name, relations)
      end
    end

    def generate_relations_helper_indexes(relations)
      create_directory(HELPERS_DATA_DIR)
      relations.each do |relation_type, linked_models|
        save_relation_foreign_keys(relation_type, linked_models) if [:many, :many_through].include?(relation_type.to_sym)
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
        when :many_through
          related_model = linked_model[:through]
          related_model_id = linked_model[:foreign_id]
        when :many
          related_model = linked_model[:relation_to]
          related_model_id = :id
      end
      save_foreign_keys(related_model, primary_id, related_model_id)
    end

    def save_foreign_keys(related_model, primary_id, related_model_id)
      results = DB[related_model.underscore.to_sym].all.each_with_object({}) do |row, results|
        add_index_to_helper_hash(results, row, primary_id, related_model_id)
      end
      write_json_to_file(HELPERS_DATA_DIR + "/#{primary_id}_#{related_model.underscore}.json", results)
    end

    def add_index_to_helper_hash(results, row, primary_id, id)
      results[row[primary_id]].nil? ? results[row[primary_id]] = [row[id]] : results[row[primary_id]] << row[id]
    end

    def map_relations_to_links(model_name, relations)
      puts "Start mapping at: #{start = Time.now}"; records = 0
      Dir.glob("#{ENTRIES_DATA_DIR}/#{model_content_type(model_name).underscore}/*json") do |entry_path|
        map_entry_relations(entry_path, model_name, relations, records)
        records += 1
      end
      import_time = JSON.parse(File.read("#{IMPORT_TIME_DIR}"))
      write_json_to_file(IMPORT_TIME_DIR, import_time.merge(model_name => {total_time: "#{((Time.now - start).to_f/60).round(2)} min.", records_mapped: "#{records}"}))
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
      Dir.glob("#{HELPERS_DATA_DIR}/#{primary_id}_#{related_model}.json") do |through_file|
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

    def map_has_one_association(linked_model, model_name, row)
      associated_model = linked_model.underscore
      foreign_key = associated_model + '_id'
      id = row[foreign_key]
      associated_content_type = mapping[linked_model][:content_type]
      link_type = contentful_field_attribute(associated_content_type, model_name, :link_type)
      api_field_id = contentful_field_attribute(associated_content_type, model_name, :id)
      if id
        file_to_modify = JSON.parse(File.read("#{ENTRIES_DATA_DIR}/#{associated_model}/#{associated_model}_#{id}.json"))
        case link_type
          when 'Array'
            File.open("#{ENTRIES_DATA_DIR}/#{associated_model}/#{associated_model}_#{id}.json", 'w') do |file|
              array = file_to_modify[api_field_id].nil? ? [] : file_to_modify[api_field_id]
              array << {
                  'type' => model_name,
                  'id' => row['id']
              }
              file.write((JSON.pretty_generate(file_to_modify.merge!(api_field_id => array))))
            end
          when 'Entry'
            puts 'NOT IMPLEMENTED YET - map_has_one_association'
          when 'Asset'
            puts 'NOT IMPLEMENTED YET - map_has_one_association'
        end
      end
    end

    ####################################################################### COMMON

    def write_json_to_file(path, data)
      File.open(path, 'w') do |file|
        file.write(JSON.pretty_generate(data))
      end
    end

  end
end