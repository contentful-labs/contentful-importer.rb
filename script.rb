require 'rubygems'
require 'active_support/core_ext/string'
require 'active_support/core_ext/hash/compact'
require 'active_support/core_ext/hash'
require 'sequel'
require 'fileutils'

class DatabaseExporter
  Sequel::Model.plugin :json_serializer
  DB = Sequel.connect('postgres://postgres:postgres@localhost/job_adder_development')

  APP_ROOT = Dir.pwd
  DATA_DIR = "#{APP_ROOT}/data"
  COLLECTIONS_DATA_DIR = "#{DATA_DIR}/collections"
  ENTRIES_DATA_DIR = "#{DATA_DIR}/entries"
  ASSETS_DATA_DIR = "#{DATA_DIR}/assets"
  LINKS_DATA = "#{DATA_DIR}/links"
  MODELS = [:job_adds, :skills, :job_add_skills, :comments, :images]

  attr_reader :contentful, :mapping


  def contentful
    contentful = {
        content_types: {
            'Job Add' => {
                id: 'job_add',
                note: 'Add new job form',
                fields: {
                    name: 'Text',
                    specification: 'Text',
                    'Image' => {
                        id: 'image',
                        link_type: 'Asset',
                    },
                    'Comment' => {
                        id: 'comments',
                        link_type: 'Array',
                        type: 'Entry'
                    },
                    'Skill' => {
                        id: 'skills',
                        link_type: 'Array',
                        type: 'Entry'
                    }
                }
            },
            'Comment' => {
                id: 'comment',
                fields: {
                    title: 'Text',
                    content: 'Text',
                }
            },
            'Skill' => {
                id: 'skill',
                fields: {
                    title: 'Text',
                }
            }
        }
    }
  end

  def mapping
    mapping = {
        'JobAdd' => {
            contentful: 'Job Add',
            type: :entry,
            fields: {
                title: :name,
                description: :specification
            },
            links: {
                keep: 'Image',
                many: 'Comment',
                many_through: {
                    relation_to: 'Skill',
                    through: 'JobAddSkill'
                }
            }
        },
        'Comment' => {
            contentful: 'Comment',
            type: :entry,
            fields: {
                title: :title,
                body: :content,
            },
            links: {
                belongs: 'JobAdd'
            }
        },
        'Skill' => {
            contentful: 'Skills',
            type: :entry,
            fields: {
                name: :title,
            },
            links: {
                #TODO REMOVE LINKS IF THEY USLESS (no need to import to contentful)
                # many_through: {
                #     relation_to: 'JobAdd',
                #     through: 'JobAddSkill'
                # }
            }
        },
        'JobAddSkills' => {
            contentful: :none,
            fields: {
            },
            links: {
                #TODO REMOVE LINKS IF THEY USLESS (no need to import to contentful)
                # belongs: 'JobAdd',
                # belongs: 'Skill'
            }
        },
        'Image' => {
            contentful: 'Image',
            type: :asset,
            fields: {
                name: :name,
                description: :description,
                url: :url
            }
        }
    }
  end


#   MESSAGE = <<-eoruby
# Actions:
#   1. Export data from Database to JSON files.
# -> Choose on of the options:
#   eoruby
#
#   def run
#     puts MESSAGE
#     action_choice = gets.to_i
#     case action_choice
#       when 1
#         export_models_from_database
#     end
#   end


  def export_models_from_database
    contentful[:content_types].each do |content_type, values|
      content_type_name = content_type.gsub(' ', '_').underscore
      FileUtils.mkdir_p COLLECTIONS_DATA_DIR unless File.directory?(COLLECTIONS_DATA_DIR)
      File.open("#{COLLECTIONS_DATA_DIR}/#{content_type_name}.json", 'w') do |file|
        collection = {
            id: values[:id],
            entry_type: content_type_name,
            note: values[:note],
            fields: []
        }
        values[:fields].each do |field, value|
          field_struct = {
              name: field.capitalize,
              identifier: value.is_a?(Hash) ? value[:id] : field,
              input_type: value.is_a?(Hash) ? value[:link_type] : value,
              link_type: value.is_a?(Hash) ? value[:type] : nil
          }.compact
          collection[:fields] << field_struct
        end
        file.write(JSON.pretty_generate(collection))
      end
    end
  end

  def save_objects_as_json
    MODELS.each do |model|
      content_type_name = model.to_s.singularize
      mapped_name = content_type_name.titleize.gsub(' ', '')
      if mapping[mapped_name] && mapping[mapped_name][:type] == :asset
        save_object_to_file(model, content_type_name, mapped_name, ASSETS_DATA_DIR)
      else
        save_object_to_file(model, content_type_name, mapped_name, ENTRIES_DATA_DIR)
      end
    end
  end

  def save_object_to_file(model, content_type_name, mapped_name, type)
    FileUtils.mkdir_p "#{type}/#{content_type_name}" unless File.directory?("#{type}/#{content_type_name}")
    DB[model].all.each do |row|
      File.open("#{type}/#{content_type_name}/#{content_type_name}_#{row[:id]}.json", 'w') do |file|
        result = row.each_with_object({}) do |(key, value), result|
          if  mapping[mapped_name] && mapping[mapped_name][:fields][key].present?
            result[mapping[mapped_name][:fields][key]] = row.delete(key)
          else
            result[key] = value
          end
          result['contentful_type'] = mapping[mapped_name][:type] if mapping[mapped_name] && mapping[mapped_name][:type].present?
        end
        result[:id] ="#{content_type_name}_#{row[:id]}"
        result.merge!(database_id: row[:id])
        file.write((JSON.pretty_generate(JSON.parse(result.to_json))))
      end
    end
  end

  def map_relationships
    Dir.glob("#{ENTRIES_DATA_DIR}/**/*json") do |file_path|
      model_name = file_path.match(/entries\/(.*)\//)[1].titleize.gsub(' ', '')
      row = JSON.parse(File.read(file_path))
      if mapping[model_name] && mapping[model_name][:links]
        mapping[model_name][:links].each do |key, linked_model|
          case key
            when :belongs
              map_belongs_association(linked_model, model_name, row)
            when :keep
              map_keep_association(linked_model, model_name, row, file_path)
            when :many_through
              map_many_through_association(linked_model, model_name, row, file_path)
          end
        end
      end
    end
  end

  def map_many_through_association(linked_model, model_name, row, file_path)
    primary_id = file_path.match(/entries\/(.*)\//)[1] + '_id'
    associated_model = linked_model[:relation_to].underscore
    foreign_key = associated_model + '_id'
    associated_content_type = mapping[model_name][:contentful]
    link_type = contentful_field_attribute(associated_content_type, associated_model, :link_type)
    api_field_id = contentful_field_attribute(associated_content_type, associated_model, :id)
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

  def map_keep_association(linked_model, model_name, row, file_path)
    associated_model = linked_model.underscore
    foreign_key = associated_model + '_id'
    id = row[foreign_key]
    content_type_name = mapping[model_name][:contentful]
    link_type = contentful_field_attribute(content_type_name, associated_model, :link_type)
    api_field_id = contentful_field_attribute(content_type_name, associated_model, :id)
    file_to_modify = JSON.parse(File.read(file_path))
    file_to_modify.delete(foreign_key)
    case link_type
      when 'Asset'
        if id
          asset = {
              '@type' => 'File',
              'asset_id' => "#{associated_model}_#{id}"
          }
          File.open(file_path, 'w') do |file|
            file.write((JSON.pretty_generate(file_to_modify.merge!(api_field_id => asset))))
          end
        end
    end
  end

  def map_belongs_association(linked_model, model_name, row)
    associated_model = linked_model.underscore
    foreign_key = associated_model + '_id'
    id = row[foreign_key]
    associated_content_type = mapping[linked_model][:contentful]
    link_type = contentful_field_attribute(associated_content_type, model_name, :link_type)
    api_field_id = contentful_field_attribute(associated_content_type, model_name, :id)
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
        puts 'NOT IMPLEMENTED YET - map_belongs_association'
      when 'Asset'
        puts 'NOT IMPLEMENTED YET - map_belongs_association'
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
    contentful[:content_types][content_type_name][:fields][associated_model.capitalize][type]
  end

  database_exporter = DatabaseExporter.new
  database_exporter.export_models_from_database
  database_exporter.save_objects_as_json
  database_exporter.map_relationships
  database_exporter.remove_database_id
  database_exporter.remove_useless_files
end
#
# MODELS.each do |model|
#   content_type_name = model.to_s.singularize
#   FileUtils.mkdir_p "#{ENTRIES_DATA_DIR}/#{content_type_name}" unless File.directory?("#{ENTRIES_DATA_DIR}/#{content_type_name}")
#   DB[model].all.each do |row|
#     File.open("#{ENTRIES_DATA_DIR}/#{content_type_name}/#{content_type_name}_#{row[:id]}.json", 'w') do |file|
#       row[:id] ="#{content_type_name}_#{row[:id]}"
#       unless mapping[content_type_name.capitalize][:links].nil?
#         name = model.to_s.singularize
#         mapping[content_type_name.capitalize][:links].each do |key, value|
#           unless row[key].nil?
#             temp_id = row[key]
#             row[key] = {url: "#{value.downcase}_#{temp_id}"}
#             FileUtils.mkdir_p "#{LINKS_DATA}/#{value.downcase}" unless File.directory?("#{LINKS_DATA}/#{value.downcase}")
#             if File.exist?("#{LINKS_DATA}/#{value.downcase}/#{value.downcase}_#{temp_id}.json")
#               links = JSON.parse(File.read("#{LINKS_DATA}/#{value.downcase}/#{value.downcase}_#{temp_id}.json"))
#               link = {
#                   '@url' => row[:id]
#               }
#               # link[name].merge!('@type' => 'File') if mapping[content_type_name.capitalize][:type] == :asset
#               File.open("#{LINKS_DATA}/#{value.downcase}/#{value.downcase}_#{temp_id}.json", 'w') { |file| file.write((JSON.pretty_generate(links.merge(name.to_sym => link)))) }
#             else
#               File.open("#{LINKS_DATA}/#{value.downcase}/#{value.downcase}_#{temp_id}.json", 'w') do |file|
#                 link = {
#                     name => {'@url' => row[:id]}
#                 }
#                 link[name].merge!('@type' => 'File') if mapping[content_type_name.capitalize][:type] == :asset
#                 file.write((JSON.pretty_generate(JSON.parse(link.to_json))))
#               end
#             end
#           end
#         end
#       end
#       file.write(JSON.pretty_generate(JSON.parse(row.to_json)))
#     end
#   end
# end

# Dir.glob("#{ENTRIES_DATA_DIR}/**/*json") do |file_path|
#   filename = File.basename(file_path)
#   catalog = file_path.match(/entries\/(.*)\//)[1]
#   if File.exists?("#{LINKS_DATA}/#{catalog}/#{filename}")
#     links = JSON.parse(File.read("#{LINKS_DATA}/#{catalog}/#{filename}"))
#     entry = JSON.parse(File.read("#{ENTRIES_DATA_DIR}/#{catalog}/#{filename}"))
#     File.open("#{ENTRIES_DATA_DIR}/#{catalog}/#{filename}", 'w') { |file| file.write(JSON.pretty_generate(entry.merge(links))) }
#   end
# end

# MODELS.each do |model|
#   content_type_name = model.to_s.singularize
#   FileUtils.mkdir_p "#{ENTRIES_DATA_DIT}/#{content_type_name}" unless File.directory?("#{ENTRIES_DATA_DIT}/#{content_type_name}")
#   DB[model].all.each do |row|
#     model_map = mapping[content_type_name.capitalize]
#     contentful_object_name = model_map[:contentful]
#     if mapping[content_type_name.capitalize][:type] == :asset
#       File.open("#{ENTRIES_DATA_DIT}/#{content_type_name}/#{content_type_name}_#{row[:id]}.json", 'w') do |file|
#       end
#     end
#   end
# end
