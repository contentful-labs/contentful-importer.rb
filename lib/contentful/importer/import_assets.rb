require_relative 'command'

module Contentful
	module Importer
		class ImportAssets < Command
			self.command = 'import-assets'
			self.summary = 'Import assets.'

			def self.import(importer)
				importer.import_only_assets
			end

			def run
				super
				self.class.import(@importer)
			end
		end
	end
end
