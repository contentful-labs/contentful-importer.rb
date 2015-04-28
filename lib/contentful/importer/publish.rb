module Contentful
	module Importer
		class Publish < Command
			require_relative 'publish_assets'
			require_relative 'publish_entries'

			self.command = 'publish'
			self.summary = 'Publish entries and assets.'

			def run
				super
				PublishAssets.publish(@settings, @importer)
				PublishEntries.publish(@importer)
			end
		end
	end
end
