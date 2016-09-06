Contentful Generic-importer
=================

## Description

This allows you to import structured JSON data to [Contentful](https://www.contentful.com).

You can use one of the following tools to extract your content and make it ready for import:

#### Available exporters

 - [Database](https://github.com/contentful/database-exporter.rb)
 - [Wordpress](https://github.com/contentful/wordpress-exporter.rb)
 - [Drupal](https://github.com/contentful/drupal-exporter.rb)


## Installation

```bash
gem install contentful-importer
```

This will install the ```contentful-importer``` executable.


## Usage

Before you can import your content to Contentful, you need to extract and prepare it. We currently support the mentioned exporters, but you can also create your own tools.

As a first step you should create a `settings.yml` file and fill in your credentials:

```yaml
#Contentful
access_token: access_token
organization_id: organization_id
```

Alternatively, you can also specify those options on the commandline.

**A Contentful OAuth access token can be created using the [Contentful Management API - documentation](https://www.contentful.com/developers/documentation/content-management-api/#getting-started)**

The Contentful organization ID can be found in your account settings, but you will only need to specify it if you are member of more than one organization.

Once you installed the Gem and created the YAML file with the settings you can invoke the tool using:

```bash
contentful-importer --configuration=settings.yml ACTION
```

## Step by step

1. Create YAML file with required parameters (eg. ```settings.yml```):

    ```yaml
    #PATH to all data
    data_dir: DEFINE_BEFORE_EXPORTING_DATA

    #JSON describing your content model
    content_model_json: PATH_TO_CONTENTFUL_MODEL_JSON_FILE

    #Contentful credentials
    access_token: ACCESS_TOKEN
    organization_id: ORGANIZATION_ID
    space_id: DEFINE_AFTER_CREATING_SPACE
    default_locale: DEFINE_LOCALE_CODE
    ```

2. First you need to create a content model using the [Contentful web application](www.contentful.com). Then you can download the content model using the content management api and use the content model for the import:

    ```bash
     curl -X GET \
          -H 'Authorization: Bearer ACCESS_TOKEN' \
          'https://api.contentful.com/spaces/SPACE_ID/content_types' > contentful_model.json
    ```

    It will create ```contentful_model.json``` file, which you can pass to the tool via the `content_model_json` option. If you are using one of our exporter tools, this will not be necessary.


3. Once you have prepared the `content types`, `assets` and `entries` (for example using one of the existing extraction adapters or creating your own) they can be imported. It can be chosen to use one (default) or two parallel threads to speedup this process.

    It is possible to import the everything in one step using the `import` action or to import content model, entries or assets individually:

    ```bash
    contentful-importer --configuration=settings.yml import --threads=2
    contentful-importer --configuration=settings.yml import-content-model
    contentful-importer --configuration=settings.yml import-entries
    contentful-importer --configuration=settings.yml import-assets
    ```

    Optionally, two threads can be used for the import.

    After each request the `success_thread_{0,1}.csv` or `success_assets.csv` file is updated. You can find those in `$data_dir/logs`.
    If an entry or asset fails to be imported, it will end up in the `failure_thread_{0,1}.csv` or `failure_assets.csv` including the error message.


4. Publish entries and assets. After successfully importing the entries and assets to contentful, they need to be published in order to be available through the delivery API.

    To publish everything that has been imported:

    ```bash
    contentful-importer --configuration=settings.yml publish
    ```

    To publish all entries use:

    ```bash
    contentful-importer --configuration=settings.yml publish-entries
    ```

    To publish all assets use:

    ```bash
    contentful-importer --configuration=settings.yml publish-assets
    ```

    or

    ```bash
    contentful-importer --configuration=settings.yml publish-assets --threads=2
    ```

    After each request the ```success_published_entries.csv``` or ```success_published_assets.csv``` file is updated. You can find those in ```data_dir/logs```.
    If an entry or asset fails to be imported, it will end up in the ```failure_published_entries.csv``` or ```failure_published_assets.csv``` including the error message.


## Actions

To display all actions use the `--help` option:

```bash
contentful-importer --help
```

#### --test-credentials

Before importing any content you can verify that your credentials in the **settings.yml** file are correct:

```bash
contentful-importer --configuration=settings.yml test-credentials
```

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

```javascript
     "SkillsTableName": {
         "content_type": "Skills",
         "type": "entry",
         "fields": { ... }
```


# Import

Before you start importing the content make sure you read [how to use it](https://github.com/contentful/generic-importer.rb#usage) and [tested your credentials](https://github.com/contentful/generic-importer.rb#--test-credentials).

#### Space ID

After [importing the content types](https://github.com/contentful/generic-importer.rb#--import-content-types-args) to the Space, you need to specify the `space_id` parameter in the settings.


Example:
```yml
space_id: space_id
```

#### Default locale

To specify in which locale you want to create all Entries and Assets, set ```default_locale``` parameter in settings.yml file:

```yml
default_locale: de-DE
```
