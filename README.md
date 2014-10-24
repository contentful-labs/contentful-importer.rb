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
For example in a ```credentials.yml``` file:

``` yaml
#Contentful
ACCESS_TOKEN: access_token
ORGANIZATION_ID: organization_id

```

**Your Contentful access token can be easiest created using the [Contentful Management API - documentation](https://www.contentful.com/developers/documentation/content-management-api/#getting-started)**
The Contentful organization id can be found in your account settings.

Once you installed the Gem and created the YAML file with the credentials you can invoke the tool using:

``` bash
contentful-importer credentials.yml
```
