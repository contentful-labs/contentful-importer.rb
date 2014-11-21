Rails database to Contentful importer
=================

## How to import Recipes database to Contentful

1. Setup settings.yml file (paths and credentials)

2. Export data from database to JSON files.

``` contentful-importer --config-file settings.yml --export-json ```

3. Create JSON files with content types

``` contentful-importer --config-file settings.yml --create-content-model-from-json ```
You can import them to existing Space:

``` contentful-importer --config-file settings.yml --import-content-types --space_id 'space_id' ```

or create new one:

``` contentful-importer --config-file settings.yml --import-content-types --space_name 'space_name' ```

4. Map models JSON files (mapping)

``` contentful-importer --config-file settings.yml --prepare-json ```

5. Special cases (mapping) only for Recipes DB.
IMPORTANT: You can do this only one time! It change structure of the file, run this once again may cause the addition of unwanted data.

``` contentful-importer --config-file settings.yml --recipes-special-mapping ```

6. Prepare files to import. Specify number of threads.

``` contentful-importer --config-file settings.yml --threads --thread 2 ```

7. Import assets only.

``` contentful-importer --config-file settings.yml --import-assets ```

8. Import entries.
``` contentful-importer --config-file settings.yml --import ```

You can import asset and entries simultaneously.




## Description

Migrate content from database to the [Contentful](https://www.contentful.com) platform

This tool exports the content from database as JSON to your local hard drive. It will allow you to import all the content on Contentful.


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
contentful-importer --config-file=settings.yml  --action
```

## Actions
To display all actions in console, use command:
```
contentful-importer -h
```
#### --list-tables
This action will create JSON file with all table names from your database and save it to ```data_dir/table_names.json```. These values ​​will be needed to export data from the database.

Specify path, where the should be saved, you can do that in **settings.yml** file.

```
 data_dir: PATH_TO_ALL_DATA
```
Path to **table_names.json**: __data_dir/table_names.json__

#### --create-content-model-from-json

Create import form JSON files with Content types

#### --export-json

In [settings.yml](https://github.com/contentful/generic-importer.rb#setting-file) file, you can define table names, which data you want to export from database. The easiest way to get table names is to use the command [--list-tables](https://github.com/contentful/generic-importer.rb#--list-tables)

#### --prepare-json

Prepare JSON files to import form to Contentful platform.

#### --threads --thread

Default value of thread: 1 (number of Threads, maximum value: 2)

Organize file structure,split them depending on number of Threads.

```
contentful-importer --config-file settings.yml --threads --thread NUMBER
```

#### --import-content-types --space_id ARG --space_name ARG

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
json_with_content_types: example_path/contentful_model.json
```

and define PATH where you want to save converted JSON file with **import structure**

``` yaml
#File with converted structure of contentful model. Almost ready to import.
import_form_dir: example_path/contentful_structure.json
```

#### --test-credentials

Before you start import data to Contentful, is goo to check if specified Contentful credentials in a **settings.yml** file are correct, use command:

```contentful-importer --config-file settings.yml --test-credentials```

## Mapping

Examples of mapping, might be found at [import-example.rb](https://github.com/contentful/importer-example.rb/tree/master/contentful_import_files)

### RELATIONS TYPES

#### belongs_to
Specifies a one-to-one association with another class.
This method should only be used if this class contains the foreign key. If the other class contains the foreign key, then you should use has_one instead.
Example:
```
    "Comments": {
        "content_type": "Comments",
        "type": "entry",
        "fields": {
            "title": "title",
            "body": "content"
        },
        "links": {
            "belongs_to": ["JobAdds"]
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
Specifies a one-to-one association with another class.
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
Specifies a one-to-many association.
Example:

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
Specifies a many-to-many relationship with another class. This associates two classes via an intermediate join table.
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

## Setting file

To use this tool, you need to create YML file and fill all needed parameters.

### Export

#### Database Connection

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
  - :job_adds
  - :skills
  - :job_add_skills
  - :comments
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

