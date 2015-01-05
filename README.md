Contentful Generic-importer
=================

## Description
Use one of our importers, which will generate the structure ready to import to the [Contentful](https://www.contentful.com) platform.

#### Available exporters
 - [Database](https://github.com/contentful/database-adapter)
 - [Wordpress](https://github.com/contentful/wordpress-adapter)
 - [Drupal](https://github.com/contentful/drupal-adapter)

## Installation

``` bash
gem install contentful-importer
```

This will install a ```contentful-importer``` executable.

## Usage
Export data from one of selected resource (```Database```,```Wordpress```,```Drupal```) using our [adapters](https://github.com/contentful/generic-importer.rb#available-exporters)
Before import data you need to specify your Contentful credentials in a YAML.
For example in a ```settings.yml``` file:

``` yaml
#Contentful
ACCESS_TOKEN: access_token
ORGANIZATION_ID: organization_id
```

**Your Contentful access token can be easiest created using the [Contentful Management API - documentation](https://www.contentful.com/developers/documentation/content-management-api/#getting-started)**
The Contentful organization id can be found in your account settings.

Once you installed the Gem and created the YAML file with the settings you can invoke the tool using:

```
contentful-importer --config-file settings.yml  --action
```

## Actions
To display all actions in console, use command:
```
contentful-importer -h
```
#### --create-contentful-model-from-json

Create import form JSON files with Content types.
Based on the structure defined in ```contentful_structure.json``` file, will be generated files with content types, ready to be imported.

Path to collections: **data_dir/collections**

```
contentful-importer --config-file settings.yml --create-contentful-model-from-json
```

#### --threads --thread

Default value of thread: 1 (number of Threads, maximum value: 2)

Organize file structure,split them depending on number of Threads.

```
contentful-importer --config-file settings.yml --threads --thread NUMBER
```

#### --import-content-types ARGS

To find an existing Space and import content types use command:

```
contentful-importer --config-file settings.yml --import-content-types --space_id SPACE_ID
```

To create a new Space and import content types use command:

```
contentful-importer --config-file settings.yml --import-content-types --space_name NAME
```

#### --import
Import data to Contentful.

```contentful-importer --config-file settings.yml --import```

#### --convert-content-model-to-json

To improve creation of the JSON file with contentful structure,needed to mapping, you can retrieve the entire structure of Space from Contentful platform and save it to the file JSON.

```ruby
 curl -X GET \
      -H 'Authorization: Bearer ACCESS_TOKEN' \
      'https://api.contentful.com/spaces/SPACE_ID/content_types' > contentful_model.json
```
In **settings.yml** file specify PATH to **contentful_model.json**.


``` yaml
#Dump file with contentful structure.
content_model_json: example_path/contentful_model.json
```

and define PATH where you want to save converted JSON file with **import structure**

``` yaml
#File with converted structure of contentful model. Almost ready to import.
import_form_dir: example_path/contentful_structure.json
```

#### --import-assets
To import only an assets, use command:

```
contentful-importer --config-file settings.yml --import-assets
```

#### --publish-assets

To publish all assets, use command:
```
contentful-importer --config-file settings.yml --publish-assets
```

#### --test-credentials

Before you start import data to Contentful, check if the specified the Contentful credentials in a **settings.yml** file are correct, use command:

```contentful-importer --config-file settings.yml --test-credentials```


## Contentful Structure

This file represents our Contentful structure.

Example:

```
{
    "Comments": {
        "id": "comment",
        "description": "",
        "displayField": "title",
        "fields": {
            "title": "Text",
            "content": "Text"
        }
    },
    "JobAdd": {
        "id": "job_add",
        "description": "Add new job form",
        "displayField": "name",
        "fields": {
            "name": "Text",
            "specification": "Text",
            "Images": {
                "id": "image",
                "link_type": "Asset"
            },
            "Comments": {
                "id": "comments",
                "link_type": "Array",
                "type": "Entry"
            },
            "Skills": {
                "id": "skills",
                "link_type": "Array",
                "type": "Entry"
            }
        }
    }
```
Key names "Images", "Comments", "Skills" are the equivalent of the content types name specified in the file **mapping.json**.

Example:
```
``
     "SkillsTableName": {
         "content_type": "Skills",
         "type": "entry",
         "fields": { ... }
```


# Import
Before you start import data, read [how to use it](https://github.com/contentful/generic-importer.rb#usage).
When you specify credentials, you can [verify them](https://github.com/contentful/generic-importer.rb#--test-credentials).

#### Space ID

After you [import content types](https://github.com/contentful/generic-importer.rb#--import-content-types-args) to Space, you need to specify ```space_id``` parameter.

Example:
```yml
space_id: space_id
```

#### Default locale

To specify in which locale you want to create all Entries and Assets, set ```default_locale``` parameter in settings.yml file

```yml
default_locale: de-DE
```




