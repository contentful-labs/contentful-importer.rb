#encoding: utf-8
require 'rubygems'
require 'active_support/core_ext/string'
require 'active_support/core_ext/hash/compact'
require 'active_support/core_ext/hash'
require 'sequel'
require 'fileutils'
require_relative 'contentful_structure'
require_relative 'contentful_mapping'

class DatabaseExporter

  include ContentfulStructure
  include ContentfulMapping

  Sequel::Model.plugin :json_serializer
  # DB = Sequel.connect('postgres://postgres:postgres@localhost/job_adder_development')
  DB = Sequel.connect(:adapter => 'mysql2', :user => 'root', :host => 'localhost', :database => 'recipes_wildeisen_ch', :password => '')
  # DB = Sequel.connect(:adapter => 'mysql2', :user => 'szpryc', :host => 'localhost', :database => 'recipes', :password => 'root')

  APP_ROOT = '/tmp' #Dir.pwd
  DATA_DIR = "#{APP_ROOT}/data"
  COLLECTIONS_DATA_DIR = "#{DATA_DIR}/collections"
  ENTRIES_DATA_DIR = "#{DATA_DIR}/entries"
  HELPERS_DATA_DIR = "#{DATA_DIR}/helpers"
  ASSETS_DATA_DIR = "#{DATA_DIR}/assets"
  LINKS_DATA = "#{DATA_DIR}/links"
  TABLES = [:user_wildeisen_alergic_info,
            :user_wildeisen_ingredient,
            :user_wildeisen_recipe,
            :user_wildeisen_recipe_to_alergic_info,
            :user_wildeisen_recipe_to_ingredient,
            :user_wildeisen_unit]

  attr_reader :contentful_structure, :mapping

  def initialize
    @contentful_structure = ContentfulStructure::STRUCTURE.with_indifferent_access
    @mapping = ContentfulMapping::MAPPING.with_indifferent_access
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

  def create_content_type_json_file(content_type_name, values)
    collection = {
        id: values[:id],
        entry_type: content_type_name,
        note: values[:note],
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
      content_type_name = mapping[model_name][:contentful].underscore
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


  def map_relations
    collect_relations.each do |model_name, relations|
      build_helper_file(model_name, relations)
      Dir.glob("#{ENTRIES_DATA_DIR}/#{model_content_type(model_name).underscore}/*json") do |entry_path|
        map_entry_relations(entry_path, model_name, relations)
      end
    end
  end

  def collect_relations
    mapping.each_with_object({}) do |(model_name, model_mapping), relations|
      relations[model_name] = model_mapping[:links] if model_mapping[:links].present?
    end
  end

  def map_entry_relations(entry_path, model_name, relations)
    relations.each do |relation_type, linked_models|
      map_entry_relation(entry_path, relation_type, linked_models, model_name)
    end
  end

  def build_helper_file(model_name, relations)
    create_directory(HELPERS_DATA_DIR)
    relations.each do |relation_type, linked_models|
      if relation_type.to_sym == :many_through
        linked_models.each do |linked_model|
          parent_key = linked_model[:parent_key]
          child_key = linked_model[:child_key]
          results = DB[linked_model[:through].underscore.to_sym].all.each_with_object({}) do |row, results|
            results[row[parent_key]] = row[child_key]
          end
          write_json_to_file(HELPERS_DATA_DIR + "/#{model_name}_#{linked_model[:relation_to]}.json", results)
        end
      end
    end
  end

  def map_entry_relation(entry_path, relation_type, linked_models, model_name)
    puts "Mapping #{model_name} - relation: #{relation_type} - #{linked_models}"
    entry = JSON.parse(File.read(entry_path))
    linked_models.each do |linked_model|
      relationships(entry, entry_path, relation_type, model_name, linked_model)
    end
  end

  #TODO REFACOTR map_many_through_association method
  def relationships(entry, entry_path, relation_type, model_name, linked_model)
    case relation_type.to_sym
      when :has_one
        # map_has_one_association(model_name, linked_model, row)
      when :belongs_to
        # map_belongs_to_association(model_name, linked_model, entry, entry_path)
      when :many_through
        # map_many_through_association(model_name, linked_model, entry, entry_path)
    end
  end

  def model_content_type(model_name)
    mapping[model_name][:contentful]
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
    foreign_key = content_type + '_id'
    foreign_id = entry.delete(foreign_key)
    if foreign_id
      case ct_link_type
        when 'Asset'
          type = 'File'
          cf_object = 'asset_id'
        when 'Entry'
          type = 'Entry'
          cf_object = '@url'
      end
      object = {
          '@type' => type,
          cf_object => "#{content_type}_#{foreign_id}"
      }
      write_json_to_file(entry_path, entry.merge!(ct_field_id => object))
    end
  end

  def map_many_through_association(model_name, linked_model, entry, entry_path)
    ct_field_id = contentful_field_attribute(model_name, linked_model[:relation_to], :id)
    save_many_through_entries(linked_model, ct_field_id, entry, entry_path)
  end

  def save_many_through_entries(linked_model, ct_field_id, entry, entry_path)
    associated_objects = entry[ct_field_id] || []
    through_model = mapping[linked_model[:through]][:contentful].underscore
    primary_id = entry_path.match(/entries\/(.*)\//)[1] + '_id'
    contentful_name = model_content_type(linked_model[:relation_to]).underscore
    foreign_key = contentful_name + '_id'
    Dir.glob("#{ENTRIES_DATA_DIR}/#{through_model}/*json") do |through_file|
      through_row = JSON.parse(File.read(through_file))
      if through_row[primary_id] == entry['database_id']
        linked_object = {
            '@type' => contentful_name,
            '@url' => "#{contentful_name}_#{through_row[foreign_key]}"
        }
        associated_objects << linked_object
      end
    end
    write_json_to_file(entry_path, entry.merge!(ct_field_id => associated_objects))
  end


  def map_has_one_association(linked_model, model_name, row)
    associated_model = linked_model.underscore
    foreign_key = associated_model + '_id'
    id = row[foreign_key]
    associated_content_type = mapping[linked_model][:contentful]
    link_type = contentful_field_attribute(associated_content_type, model_name, :link_type)
    api_field_id = contentful_field_attribute(associated_content_type, model_name, :id)
    if id
      file_to_modify = JSON.parse(File.read("#{ENTRIES_DATA_DIR}/#{associated_model}/#{associated_model}_#{id}.json"))
      case link_type
        when 'Array'
          File.open("#{ENTRIES_DATA_DIR}/#{associated_model}/#{associated_model}_#{id}.json", 'w') do |file|
            array = file_to_modify[api_field_id].nil? ? [] : file_to_modify[api_field_id]
            entry = {
                '@type' => model_name,
                '@url' => row['id']
            }
            array << entry
            file.write((JSON.pretty_generate(file_to_modify.merge!(api_field_id => array))))
          end
        when 'Entry'
          puts 'NOT IMPLEMENTED YET - map_has_one_association'
        when 'Asset'
          puts 'NOT IMPLEMENTED YET - map_has_one_association'
      end
    end
  end

  def remove_database_id
    Dir.glob("#{DATA_DIR}/**/**/*json") do |file_path|
      clean_file = JSON.parse(File.read(file_path))
      clean_file.delete('database_id')
      File.open(file_path, 'w') { |file| file.write(JSON.pretty_generate(clean_file)) }
    end
  end

  def remove_useless_files
    mapping.each do |key, value|
      FileUtils.rm_rf("#{ENTRIES_DATA_DIR}/#{key.underscore.singularize}") if value[:contentful] == :none
    end
  end


  ####################################################################### COMMON


  def write_json_to_file(path, data)
    File.open(path, 'w') do |file|
      file.write(JSON.pretty_generate(data))
    end
  end

end


database_exporter = DatabaseExporter.new
# database_exporter.export_models_from_database
# database_exporter.save_objects_as_json
database_exporter.map_relations
# database_exporter.remove_database_id
# database_exporter.remove_useless_files