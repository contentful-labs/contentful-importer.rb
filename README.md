Rails database to Contentful importer
=================

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

``` bash
contentful-importer --file=credentials.yml  --action
```

## Actions
#### --list-tables

List and save to JSON file all tables name from database. Path: ``` data_dir/tables.json```

#### --export-json

Export data from models to JSON files.

#### --prepare-json

Prepare JSON files to import form to Contentful platform.

#### --import-content-types --count 5

default value of count: 1

contentful-importer --file settings.yml --import-content-types --count 5

#### --import

contentful-importer --file settings.yml --parallel-import --count 5

Import data to Contentful.

#### --convert-json

Convert dump from Contentful model to JSON file.

#### --test-credentials

Test contentful credentials.


## Mapping

#### belongs_to
 keep ID in current model

#### has_one
 add ID to belonged model

#### many
 add another table IDs to current model

#### many_through
map join table, add IDs to current model