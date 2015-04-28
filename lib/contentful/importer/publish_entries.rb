require_relative 'command'

module Contentful
	module Importer
		class PublishEntries < Command
			self.command = 'publish-entries'
			self.summary = 'Publish entries.'

			def self.options
				super.concat(data_options).sort
			end

			def self.publish(importer)
				importer.publish_entries_in_threads
			end

			def run
				super
				self.class.publish(@importer)
			end
		end
	end
end
