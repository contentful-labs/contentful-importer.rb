module Contentful
	module Importer
		class Import < Command
			require_relative 'import_assets'
			require_relative 'import_entries'
			require_relative 'import_model'

			self.command = 'import'
			self.summary = 'Import content model, entries and assets.'

			def run
				super

				ImportModel.import(@settings, @converter, @importer)
				ImportEntries.import(@settings, @importer)
				ImportAssets.import(@importer)
			end
		end
	end
end
