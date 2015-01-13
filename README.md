Contentful Generic-importer
=================

## Description

A generic importer for [Contentful](https://www.contentful.com).
It uses JSON to create the content types, entries and assets.

You can use one of the following tools to extract your content and prepare it to be imported to [Contentful](https://www.contentful.com):


#### Available exporters

 - [Database](https://github.com/contentful/database-adapter)
 - [Wordpress](https://github.com/contentful/wordpress-adapter)
 - [Drupal](https://github.com/contentful/drupal-adapter)

## Installation

```bash
gem install contentful-importer
```

This will install the ```contentful-importer``` executable.

## Usage

Export data from one of selected resource (```Database```,```Wordpress```,```Drupal```) using our [adapters](https://github.com/contentful/generic-importer.rb#available-exporters)
Before import data you need to specify your Contentful credentials in a YAML.
For example in a ```settings.yml``` file:

```yaml
#Contentful
ACCESS_TOKEN: access_token
ORGANIZATION_ID: organization_id
```

**Your Contentful oauth access token can be created using the [Contentful Management API - documentation](https://www.contentful.com/developers/documentation/content-management-api/#getting-started)**

The Contentful organization id can be found in your account settings.

Once you installed the Gem and created the YAML file with the settings you can invoke the tool using:

```bash
contentful-importer --config-file settings.yml --action
```

## Actions

To display all actions use the `-h` option:

```bash
contentful-importer -h
```

#### --create-contentful-model-from-json

Create the content model based on the structure defined in ```contentful_structure.json```.
This will generate files with Contentful content types that are ready to be imported.

Path to collections: **data_dir/collections**

```bash
contentful-importer --config-file settings.yml --create-contentful-model-from-json
```

#### --threads --thread

Default value of thread: 1 (number of Threads, maximum value: 2)

Organize file structure,split them depending on number of Threads.

```bash
contentful-importer --config-file settings.yml --threads --thread NUMBER
```

#### --import-content-types ARGS

To import the content types into an existing space use `--space_id SPACE_ID`:

```bash
contentful-importer --config-file settings.yml --import-content-types --space_id SPACE_ID
```

To create a new Space and import content types use `--space_name NAME`:

```bash
contentful-importer --config-file settings.yml --import-content-types --space_name NAME
```

#### --import
Import the content as entries:

```bash
contentful-importer --config-file settings.yml --import
```

#### --convert-content-model-to-json

If you already have an existing content model for a space it can be downloaded and used for the import:

```bash
 curl -X GET \
      -H 'Authorization: Bearer ACCESS_TOKEN' \
      'https://api.contentful.com/spaces/SPACE_ID/content_types' > contentful_model.json
```


In the **settings.yml** specify the PATH to **contentful_model.json**.

```yaml
#Dump file with content model.
content_model_json: example_path/contentful_model.json
```

and define the PATH where you want to save the converted JSON file:

```yaml
#File with converted structure of contentful model. Almost ready to import.
import_from_dir: example_path/contentful_structure.json
```

#### --import-assets

To import only the assets use:

```bash
contentful-importer --config-file settings.yml --import-assets
```

#### --publish-assets

To publish all assets:

```bash
contentful-importer --config-file settings.yml --publish-assets
```

#### --test-credentials

Before importing content to Contentful, check if the credentials in your **settings.yml** file are correct:

```bash
contentful-importer --config-file settings.yml --test-credentials
```

#### --validate-schema

After preparing the files to import, you can validate the JSON schema, use command:

```contentful-importer --config-file settings.yml --validate-schema```

## Content Model

This represents an example content model:

```javascript
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
Key names "Images", "Comments", "Skills" are the equivalent of the content type names specified in the file **mapping.json**.

Example:
```
``
     "SkillsTableName": {
         "content_type": "Skills",
         "type": "entry",
         "fields": { ... }
```


# Import

Before you start importing the content make sure you read [how to use it](https://github.com/contentful/generic-importer.rb#usage) and [tested your credentials](https://github.com/contentful/generic-importer.rb#--test-credentials).

#### Space ID

After [importing the content types](https://github.com/contentful/generic-importer.rb#--import-content-types-args) to the Space, you need to specify ```space_id``` parameter in the settings.

Example:
```yml
space_id: space_id
```

#### Default locale

To specify in which locale you want to create all Entries and Assets, set ```default_locale``` parameter in settings.yml file:

```yml
default_locale: de-DE
```
