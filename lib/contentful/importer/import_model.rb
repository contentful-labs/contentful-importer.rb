require_relative 'command'

module Contentful
	module Importer
		class ImportModel < Command
			self.command = 'import-content-model'
			self.summary = 'Import the content model.'

			def self.import(settings, converter, importer)
				if settings['content_model_json']
					converter.convert_to_import_form
					converter.create_content_type_json
				end

				importer.create_contentful_model(settings)
			end

			def run
				super
				self.class.import(@settings, @converter, @importer)
			end
		end
	end
end
