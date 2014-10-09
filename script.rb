require 'rubygems'
require 'active_support/core_ext/string'
require 'active_support/core_ext/hash/compact'
require 'sequel'
require 'fileutils'


DB = Sequel.connect('postgres://postgres:postgres@localhost/blog_development')
Sequel::Model.plugin :json_serializer

APP_ROOT = Dir.pwd
DATA_DIR = "#{APP_ROOT}/data"
COLLECTIONS_DATA_DIR = "#{DATA_DIR}/collections"
ENTRIES_DATA_DIR = "#{DATA_DIR}/entries"
LINKS_DATA = "#{DATA_DIR}/links"

MODELS = [:categories, :posts, :photos, :comments]
contentful = {
    content_types: {
        'Category' => {
            id: 'category_content_type',
            note: 'Some description - Category',
            fields: {
                name: 'Text',
                description: 'Text'
            }
        },
        'Post' => {
            id: 'post_content_type',
            fields: {
                title: 'Text',
                body: 'Text',
                category: {
                    link_type: 'Entry',
                    type: 'Category'
                },
                images: {
                    link_type: 'Array',
                    link: 'Asset',
                    type: 'Image'
                },
                comment: {
                    link_type: 'Entry',
                    type: 'Comment'
                }
            }
        },
        'Comment' => {
            id: 'comment_content_type',
            fields: {
                author: 'Text',
                body: 'Text',
            }
        }
    },
    assets: {
        'Image' => {
            title: 'Text',
            description: 'Text',
            url: 'Text'
        }
    }
}

# rails_name => contentful_api_name
mapping = {
    'Category' => {
        contentful: 'Category',
        type: :entry,
        fields: {
            name: :name,
            description: :description
        },
        links: {
            post_id: 'Post'
        }
    },
    'Photo' => {
        contentful: 'Image',
        type: :asset,
        fields: {
            title: :title,
            description: :description,
            url: :url
        },
        links: {
            post_id: 'Post'
        }
    },
    'Post' => {
        contentful: 'Post',
        type: :entry,
        fields: {
            title: :title,
            body: :body
        },
        links: {
            category_id: 'Category',
            photo_id: 'Image',
            comment_id: 'Comment'
        }
    },
    'Comment' => {
        contentful: 'Comment',
        type: :entry,
        fields: {
            posted_by: :author,
            body: :body,
        },
        links: {
            post_id: 'Post'
        }
    }
}

#Create JSON file with collections(models)
contentful[:content_types].each do |content_type, values|
  FileUtils.mkdir_p COLLECTIONS_DATA_DIR unless File.directory?(COLLECTIONS_DATA_DIR)
  File.open("#{COLLECTIONS_DATA_DIR}/#{content_type.downcase}.json", 'w') do |file|
    collection = {
        id: values[:id],
        entry_type: content_type,
        note: values[:note],
        fields: []
    }
    values[:fields].each do |field, value|
      field_struct = {
          name: field.capitalize,
          identifier: field,
          input_type: value.is_a?(Hash) ? value[:link_type] : value,
          link_type: value.is_a?(Hash) ? value[:link] : value
      }.compact
      collection[:fields] << (field_struct)
    end
    file.write(JSON.pretty_generate(collection))
  end
end

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

MODELS.each do |model|
  content_type_name = model.to_s.singularize
  FileUtils.mkdir_p "#{ENTRIES_DATA_DIR}/#{content_type_name}" unless File.directory?("#{ENTRIES_DATA_DIR}/#{content_type_name}")
  DB[model].all.each do |row|
    File.open("#{ENTRIES_DATA_DIR}/#{content_type_name}/#{content_type_name}_#{row[:id]}.json", 'w') do |file|
      row[:id] ="#{content_type_name}_#{row[:id]}"
      unless mapping[content_type_name.capitalize][:links].nil?
        name = model.to_s.singularize
        mapping[content_type_name.capitalize][:links].each do |key, value|
          unless row[key].nil?
            temp_id = row[key]
            row[key] = {url: "#{value.downcase}_#{temp_id}"}
            FileUtils.mkdir_p "#{LINKS_DATA}/#{value.downcase}" unless File.directory?("#{LINKS_DATA}/#{value.downcase}")
            if File.exist?("#{LINKS_DATA}/#{value.downcase}/#{value.downcase}_#{temp_id}.json")
              links = JSON.parse(File.read("#{LINKS_DATA}/#{value.downcase}/#{value.downcase}_#{temp_id}.json"))
              link = {
                  '@url' => row[:id]
              }
              # link[name].merge!('@type' => 'File') if mapping[content_type_name.capitalize][:type] == :asset
              File.open("#{LINKS_DATA}/#{value.downcase}/#{value.downcase}_#{temp_id}.json", 'w') { |file| file.write((JSON.pretty_generate(links.merge(name.to_sym => link)))) }
            else
              File.open("#{LINKS_DATA}/#{value.downcase}/#{value.downcase}_#{temp_id}.json", 'w') do |file|
                link = {
                    name => {'@url' => row[:id]}
                }
                link[name].merge!('@type' => 'File') if mapping[content_type_name.capitalize][:type] == :asset
                file.write((JSON.pretty_generate(JSON.parse(link.to_json))))
              end
            end
          end
        end
      end
      file.write(JSON.pretty_generate(JSON.parse(row.to_json)))
    end
  end
end

Dir.glob("#{ENTRIES_DATA_DIR}/**/*json") do |file_path|
  filename = File.basename(file_path)
  catalog = file_path.match(/entries\/(.*)\//)[1]
  if File.exists?("#{LINKS_DATA}/#{catalog}/#{filename}")
    links = JSON.parse(File.read("#{LINKS_DATA}/#{catalog}/#{filename}"))
    entry = JSON.parse(File.read("#{ENTRIES_DATA_DIR}/#{catalog}/#{filename}"))
    File.open("#{ENTRIES_DATA_DIR}/#{catalog}/#{filename}", 'w') { |file| file.write(JSON.pretty_generate(entry.merge(links))) }
  end
end
