require_relative 'command'

module Contentful
	module Importer
		class ImportEntries < Command
			self.command = 'import-entries'
			self.summary = 'Import entries.'

			def self.options
				super.concat(data_options).concat(space_options).concat(thread_options).sort
			end

			def self.import(settings, importer)
				importer.import_data(settings[:threads])
			end

			def run
				super
				self.class.import(@settings, @importer)
			end
		end
	end
end
