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

  APP_ROOT = '/tmp/' #Dir.pwd
  DATA_DIR = "#{APP_ROOT}/data"
  COLLECTIONS_DATA_DIR = "#{DATA_DIR}/collections"
  ENTRIES_DATA_DIR = "#{DATA_DIR}/entries"
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
    @contentful_structure = ContentfulStructure::STRUCTURE
    @mapping = ContentfulMapping::MAPPING
  end

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
    File.open("#{COLLECTIONS_DATA_DIR}/#{content_type_name}.json", 'w') do |file|
      collection = {
          id: values[:id],
          entry_type: content_type_name,
          note: values[:note],
          fields: create_fields(values[:fields])
      }
      file.write(JSON.pretty_generate(collection))
    end
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
    DB[table].all.each_with_index do |row|
      raise "Missing id! #{row}" unless row[:id]
      id = row[:id]
      File.open("#{type}/#{content_type_name}/#{content_type_name}_#{id}.json", 'w') do |file|
        puts "Saving #{content_type_name} - id: #{id}"
        db_object = change_keys_in_mapped_hash(row, model_name)
        db_object[:id] ="#{content_type_name}_#{id}"
        db_object[:database_id] = id
        result = JSON.parse(db_object.to_json)
        file.write((JSON.pretty_generate(result)))
      end
    end
  end

  def change_keys_in_mapped_hash(row, mapped_name)
    row.each_with_object({}) do |(key, value), result|
      if mapping[mapped_name] && mapping[mapped_name][:fields][key].present?
        result[mapping[mapped_name][:fields][key]] = row.delete(key)
      else
        result[key] = value.is_a?(String) ? value.force_encoding('ISO-8859-1') : value
      end
    end
  end

  #######################################################################

  def map_relationships
    Dir.glob("#{ENTRIES_DATA_DIR}/**/*json") do |file_path|
      contentful_model_name = file_path.match(/entries\/(.*)\//)[1].titleize.gsub(' ', '')
      row = JSON.parse(File.read(file_path))
      model_name = mapping.each { |key, value| break key if value[:contentful] == contentful_model_name }
      if mapping[model_name] && mapping[model_name][:links]
        mapping[model_name][:links].each do |key, linked_model|
          if linked_model.is_a? Array
            linked_model.each do |relation_with|
              contentful_name = mapped_contentful_name(relation_with[:relation_to])
              relationships(key, model_name, contentful_name, row, file_path)
            end
          else
            contentful_name = mapped_contentful_name(linked_model)
            relationships(key, model_name, contentful_name, row, file_path)
          end
        end
      end
    end
  end

  #TODO REFACOTR map_many_through_association method
  def relationships(key, model_name, contentful_name, row, file_path)
    case key
      when :has_one
        map_has_one_association(model_name, contentful_name, row)
      when :belongs_to
        # map_belongs_to_association(model_name, contentful_name, row, file_path)
      when :many_through
        # map_many_through_association(model_name, contentful_name, row, file_path)
    end
  end

  def mapped_contentful_name(linked_model)
    mapping[linked_model][:contentful]
  end

  def map_many_through_association(model_name, linked_model, row, file_path)
    primary_id = file_path.match(/entries\/(.*)\//)[1] + '_id'
    foreign_key = linked_model + '_id'
    associated_content_type = mapping[model_name][:contentful]
    link_type = contentful_field_attribute(associated_content_type, linked_model, :link_type)
    api_field_id = contentful_field_attribute(associated_content_type, linked_model, :id)
    file_to_modify = JSON.parse(File.read(file_path))
    case link_type
      when 'Array'
        File.open(file_path, 'w') do |file|
          array = file_to_modify[api_field_id].nil? ? [] : file_to_modify[api_field_id]
          through_model = linked_model[:through].underscore
          Dir.glob("#{ENTRIES_DATA_DIR}/#{through_model}/*json") do |through_file|
            through_row = JSON.parse(File.read(through_file))
            if through_row[primary_id] == row['database_id']
              linked_object = {
                  '@type' => associated_model,
                  '@url' => "#{associated_model}_#{through_row[foreign_key]}"
              }
              array << linked_object
            end
          end
          file.write((JSON.pretty_generate(file_to_modify.merge!(api_field_id => array))))
        end
    end
  end

  def map_belongs_to_association(model_name, linked_model, row, file_path)
    associated_model = linked_model.underscore
    foreign_key = associated_model + '_id'
    id = row[foreign_key]
    content_type_name = mapping[model_name][:contentful]
    link_type = contentful_field_attribute(content_type_name, associated_model, :link_type)
    api_field_id = contentful_field_attribute(content_type_name, associated_model, :id)
    file_to_modify = JSON.parse(File.read(file_path))
    file_to_modify.delete(foreign_key)
    if id
      case link_type
        when 'Asset'
          save_belongs_to_associated_file(id, api_field_id, associated_model, file_to_modify, file_path, 'File', 'asset_id')
        when 'Entry'
          save_belongs_to_associated_file(id, api_field_id, associated_model, file_to_modify, file_path, 'Entry', '@url')
      end
    end
  end

  def save_belongs_to_associated_file(id, api_field_id, associated_model, file_to_modify, file_path, type, cf_object)
    object = {
        '@type' => type,
        cf_object => "#{associated_model}_#{id}"
    }
    File.open(file_path, 'w') do |file|
      file.write((JSON.pretty_generate(file_to_modify.merge!(api_field_id => object))))
    end
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


  def contentful_field_attribute(content_type_name, associated_model, type)
    contentful_field = contentful_structure[content_type_name][:fields]
    contentful_field[associated_model] ? contentful_field[associated_model][type] : contentful_field[associated_model.capitalize][type]
  end

  database_exporter = DatabaseExporter.new
  database_exporter.export_models_from_database
  database_exporter.save_objects_as_json
  # database_exporter.map_relationships
  # database_exporter.remove_database_id
  # database_exporter.remove_useless_files
end
