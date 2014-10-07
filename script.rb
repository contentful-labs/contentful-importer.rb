require 'rubygems'
require 'contentful/management'
require 'sequel'
require 'fileutils'

DB = Sequel.connect('postgres://postgres:postgres@localhost/blog_development')
Sequel::Model.plugin :json_serializer

APP_ROOT = Dir.pwd
DATA_DIR = "#{APP_ROOT}/data"
COLLECTIONS_DATA_DIR = "#{DATA_DIR}/collections"
ENTRIES_DATA_DIT = "#{DATA_DIR}/entries"
ACCESS_TOKEN = 'e548877d1c317ee58e5710c793bd2d92419149b1e3c50d47755a19a5deadda00'
ORGANIZATION_ID = '1EQPR5IHrPx94UY4AViTYO'

# Contentful::Management::Client.new(ACCESS_TOKEN)

# space = Contentful::Management::Space.find('7xgjcamot3y7')

contentful = {
    content_types: {
        'Category' => {
            type: :entry,
            id: 'category_content_type',
            note: 'Some description - Category',
            fields: {
                name: 'Text',
                description: 'Text'
            }
        },
        'Post' => {
            type: :entry,
            id: 'post_content_type',
            fields: {
                title: 'Text',
                body: 'Text',
                categories: {
                    link_type: 'Entry',
                    type: 'Category'
                },
                images: {
                    link_type: 'Asset',
                    type: 'Image'
                }
            }
        }
    },
    assets: {
        'Image' => {
            type: :asset,
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
        fields: {
            name: :name,
            description: :description
        }
    },
    'Photo' => {
        contentful: 'Image',
        fields: {
            title: :title,
            description: :description,
            url: :url
        }
    },
    'Post' => {
        contentful: 'Post',
        fields: {
            title: :title,
            body: :body
        },
        links: [
            category_id: 'Category',
            photo_id: 'Image'
        ]
    }
}

class Post < Sequel::Model
end

class Category < Sequel::Model
end

class Photo < Sequel::Model
end

#Create JSON file with collections(models)
contentful[:content_types].each do |content_type, values|
  FileUtils.mkdir_p COLLECTIONS_DATA_DIR unless File.directory?(COLLECTIONS_DATA_DIR)
  File.open("#{COLLECTIONS_DATA_DIR}/#{content_type.downcase}.json", 'w') do |file|
    collection = {
        type: values[:type],
        id: values[:id],
        entry_type: content_type,
        note: values[:note],
        fields: []
    }
    values[:fields].each do |field, value|
      field_struct = {
          name: field.capitalize,
          identifier: field,
          input_type: value.is_a?(Hash) ? value[:link_type] : value
      }
      collection[:fields] << (field_struct)
    end
    file.write(JSON.pretty_generate(collection))
  end
end
[Category, Post, Photo].each do |model|
  content_type_name = mapping[model.to_s][:contentful].downcase
  FileUtils.mkdir_p "#{ENTRIES_DATA_DIT}/#{content_type_name}" unless File.directory?("#{ENTRIES_DATA_DIT}/#{content_type_name}")
  model.all.each do |row|
    File.open("#{ENTRIES_DATA_DIT}/#{content_type_name}/#{content_type_name}_#{row[:id]}.json", 'w') do |file|
      file.write(JSON.pretty_generate(JSON.parse(row.to_json)))
    end
  end
end
