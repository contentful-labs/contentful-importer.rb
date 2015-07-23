require 'claide'
require 'yaml'

require_relative 'parallel_importer'
require_relative 'configuration'
require_relative 'converters/contentful_model_to_json'
require_relative 'json_schema_validator'
require_relative 'version'

module Contentful
	module Importer
		class PlainInformative < StandardError
			include CLAide::InformativeError
		end

		class Informative < PlainInformative
			def message
				"[!] #{super}".red
			end
		end

		class Command < CLAide::Command
			require_relative 'import'
			require_relative 'import_assets'
			require_relative 'import_entries'
			require_relative 'import_model'
			require_relative 'publish'
			require_relative 'publish_assets'
			require_relative 'publish_entries'
			require_relative 'test_credentials'

			attr_reader :importer, :converter, :config, :json_validator

			self.abstract_command = true
			self.command = 'contentful-importer'
			self.version = VERSION
			self.description = 'Import structured JSON data to Contentful.'

			def self.options
				[['--configuration=config.yaml', 'Use the given configuration file.'],
				 ['--access_token=XXX', 'The CMA access token to be used.']].concat(super).sort
			end

			def self.data_options
				[['--data_dir=data', 'The directory to use for input, temporary data and logs.']]
			end

			def self.space_options
				[['--organization_id=YYY', 'Select organization if you are member of more than one.'],
				 ['--space_id=ZZZ', 'Import into an existing space.'],
				 ['--space_name=ZZZ', 'Import into a new space with the given name.'],
				 ['--default_locale=de-DE', 'Locale to use if a new space is being created.']]
			end

			def self.thread_options
				[['--threads=1', 'Number of threads to be used, can be either 1 or 2.']]
			end

			def initialize(args)
				super(args)

				@settings = {}

				settings_file = args.option('configuration')
				@settings.merge!(YAML.load_file(settings_file)) if settings_file

				# CLI options can override settings of the same name
				self.class.options.map { |opt| opt.first.split('=').first.split('-').last }.each do |opt|
					arg = args.option(opt)
					arg = arg.to_i if opt == 'threads'
					@settings[opt] = arg if arg
				end

				@settings = @settings.with_indifferent_access
				@settings[:threads] = 1 if @settings[:threads].nil?
			end

			def run
				@config = Configuration.new(@settings)
				@importer = ParallelImporter.new(@config)
				@converter = ContentfulModelToJson.new(@config)
				@json_validator = JsonSchemaValidator.new(@config)

				json_validator.validate_schemas
			end
		end
	end
end
