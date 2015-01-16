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
access_token: access_token
organization_od: organization_id
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

## Step by step

1. Create YAML file with required parameters (eg. ```settings.yml```):

    ```yaml
    #PATH to all data
    data_dir: DEFINE_BEFORE_EXPORTING_DATA

    #Contentful credentials
    access_token: ACCESS_TOKEN
    organization_id: ORGANIZATION_ID
    space_id: DEFINE_AFTER_CREATING_SPACE
    default_locale: DEFINE_LOCALE_CODE

    ## CONTENTFUL STRUCTURE
    contentful_structure_dir: PATH_TO_CONTENTFUL_STRUCTURE_JSON_FILE

    ## CONVERT CONTENTFUL MODEL TO CONTENTFUL IMPORT STRUCTURE
    content_model_json:
    converted_model_dir:
    ```

2. Create the contentful_structure.json. First you need to create a content model using the [contentful website](www.contentful.com). Then you can download the content model using the content management api and use as the schema for the import structure.

    ```bash
     curl -X GET \
          -H 'Authorization: Bearer ACCESS_TOKEN' \
          'https://api.contentful.com/spaces/SPACE_ID/content_types' > contentful_model.json
    ```

    It will create ```contentful_model.json``` file, which you need to transform into the ```contentful_structure.json``` using:

    ```
    contentful-importer --config-file settings.yml --convert-content-model-to-json
    ```

    The converted content model will be saved as JSON file in the ```converted_model_dir``` path.

3. Once you have prepared the ```content types```, ```assets``` and ```entries``` (for example using one of the existing extraction adapters or creating your own) they can be imported. It can be chosen to use one (default) or two parallel threads to speedup this process.

    ```
    contentful-importer --config-file settings.yml --threads --thread 2
    ```

4. Import data: There are two steps to import entries and assets.

    **Entries**

    ```
    contentful-importer --config-file settings.yml --import
    ```

    **Assets**

    ```
    contentful-importer --config-file settings.yml --import-assets
    ```

    After each request the ```success_number_of_thread.csv``` or ```success_assets``` file is updated. You can find it in ```data_dir/logs```.
    If an entry or asset fails to be imported, it will end up in the ```failure_number_of_thread``` or ```assets_failure.csv``` including the error message.


5. Publish entries and assets. After successfully importing the entries and assets to contentful, they need to be published in order to be available through the delivery API.

    To publish an entries use:

    ```
    contentful-importer --config-file settings.yml --publish-entries
    ```

    To publish an assets use:

    ```
    contentful-importer --config-file settings.yml --publish-assets
    ```
    After each request the ```success_published_entries.csv``` or ```success_published_assets.csv``` file is updated. You can find it in ```data_dir/logs```.
    If an entry or asset fails to be imported, it will end up in the ```failure_published_entries.csv``` or ```failure_published_assets.csv``` including the error message.
