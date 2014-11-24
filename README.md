Rails database to Contentful importer
=================

## Description

Migrate data from database to the [Contentful](https://www.contentful.com) platform.

This tool fetch data from database and save as JSON file on your local hard drive. It will allow you to import database's data to Contentful.

## Installation

``` bash
gem install contentful-importer
```

This will install a ```contentful-importer``` executable.

## Usage

To use the tool you need to specify your Contentful credentials in a YAML file and database configuration .
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
#### --list-tables
This action will create JSON file with all table names from your database and save it to ```data_dir/table_names.json```. These values ​​will be needed to export data from the database.

Specify path, where the should be saved, you can do that in **settings.yml** file.

```yml
 data_dir: PATH_TO_ALL_DATA
 table_names: data_dir/table_names.json
```

#### --create-content-model-from-json

Create import form JSON files with Content types.
Based on the structure defined in ```contentful_structure.json``` file, will be generated files with content types, ready to be imported.

Path to collections: **data_dir/collections**

#### --export-json

In [settings.yml](https://github.com/contentful/generic-importer.rb#setting-file) file, you can define table names, which data you want to export from database. The easiest way to get table names is to use the command [--list-tables](https://github.com/contentful/generic-importer.rb#--list-tables)

After we specify the tables, that we want to extract, and run command ```--export-json ```, each object from database will be save to separate JSON file.

Path to JSON data: ***data_dir/entries/content_type_name_defined_in_mapping_json_file***

#### --prepare-json

Prepare JSON files to import form to Contentful platform.

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

#### --convert-json

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

#### --test-credentials

Before you start import data to Contentful, check if the specified the Contentful credentials in a **settings.yml** file are correct, use command:

```contentful-importer --config-file settings.yml --test-credentials```

## Mapping

Examples of mapping, might be found at [import-example.rb](https://github.com/contentful/importer-example.rb/tree/master/contentful_import_files)

### RELATIONS TYPES

#### belongs_to

This method should only be used if this class contains the foreign key. If the other class contains the foreign key, then you should use has_one instead.

Example:
```
    "Comments": {
        "content_type": "Comments",
        "type": "entry",
        "fields": {
        },
        "links": {
           "belongs_to": [
                          {
                              "relation_to": "JobAdds",
                              "foreign_id": "job_add_id"
                          }
                      ]
        }
    }
```
It will assign the associate object, save his ID ```(model_name + id)``` in JSON file.

Result:
```
{
  "id": "comments_1",
  ...
  "job_add_id": {
    "type": "Entry",
    "id": "job_adds_1"
  },
}

```

#### has_one

This method should only be used if the other class contains the foreign key. If the current class contains the foreign key, then you should use belongs_to instead.

 Example:

 ```
     "Users": {
         "content_type": "Users",
         "type": "entry",
         "fields": {
         },
         "links": {
             "has_one": [
                 {
                     "relation_to": "Profiles",
                     "primary_id": "user_id"
                 }
             ]
         }
     }
 ```

Results:
It will assign the associate object, save his ID ```(model_name + id)``` in JSON file.

_users/users1.json_
 ```
 ...
  "profile": {
    "type": "profiles",
    "id": "profiles_3"
  }
 ```

#### many

```
    "JobAdds": {
    ...
        },
        "links": {
            "many": [
                        {
                            "relation_to": "Comments",
                            "primary_id": "job_add_id"
                        }
                    ],
                }
        }
```

It will assign the associate objects, save his ID ```(model_name + id)``` in JSON file.

Results:

Example:
```
{
  "id": "job_adds_1",
  ...

  "comments": [
    {
      "type": "comments",
      "id": "comments_1"
    },
    {
      "type": "comments",
      "id": "comments_2"
    },
    {
      "type": "comments",
      "id": "comments_4"
    },
    {
      "type": "comments",
      "id": "comments_7"
    }
  ]
}
```

#### many_through
Example:

```
        "links": {
            "many_through": [
                {
                    "relation_to": "Skills",
                    "primary_id": "job_add_id",
                    "foreign_id": "skill_id",
                    "through": "JobAddSkills"
                }
            ]
        }
```

It will map join table and save objects IDs in current model.

Results:
_users/job_adds_1.json_

```
  "skills": [
    {
      "type": "skills",
      "id": "skills_1"
    },
    {
      "type": "skills",
      "id": "skills_2"
    },
    {
      "type": "skills",
      "id": "skills_3"
    }
  ]
```

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

**IMPORTANT**

To create any relationship between objects, we must remember that the content names given in the  **mapping.json** file, must cover with names in **contentful_structure.json** file.

## Setting file

To use this tool, you need to create YML file and define all needed parameters.

### Export

#### Database Connection - Define Adapter

Assuming we are going to work with MySQL, SQlite or PostgreSQL database, before connecting to a database make sure of the setup YML file with settings.
Following is the example of connecting with MySQL database "test_import"

```yml
adapter: mysql2
user: username
host: localhost
database: test_import
password: secret_password
```

**Available Adapters**

```
PostgreSQL => postgres
MySQL => mysql2
SQlite => sqlite
```

**Define Exporter**

By default we set Database Exporter. To change Exporter you need to specify addition argument ``` --exporter EXPORTER ```. For now there is only exporter available.

``` contentful-importer --config-file settings.yml  --exporter database --action ```

#### Mapped tables

Before export data from database, you need to exactly specify which tables will be exported.
To fastest way to get that names is use command: [--list-tables](https://github.com/contentful/generic-importer.rb#--list-tables)

Selected table names enter to **settings.yml** file, parameter
 ```yml
mapped:
    tables:
```
Example:
 ```yml
mapped:
 tables:
  - :example_1
  - :example_2
  - :example_3
  - :example_4
```

### Mapping

* JSON file with mapping structure which defines relations between models.

```yml
mapping_dir: example_path/mapping.json
```

* JSON file with contentful structure
```yml
contentful_structure_dir: contentful_import_files/contentful_structure.json
```
* [Dump JSON file](https://github.com/contentful/generic-importer.rb#--convert-json) with content types from contentful model:

```yml
import_form_dir: contentful_import_files/contentful_structure.json
```

### Import
Before you start import data, read [how to use it](https://github.com/contentful/generic-importer.rb#usage).
When you specify credentials, you can [test them](https://github.com/contentful/generic-importer.rb#--test-credentials).

After you [import content types](https://github.com/contentful/generic-importer.rb#--import-content-types---space_id-arg---space_name-arg) to Space, you need to specify ```space_id``` parameter.

Example:
```yml
space_id: space_id
```

