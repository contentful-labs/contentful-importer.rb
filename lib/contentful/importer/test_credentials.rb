module Contentful
	module Importer
		class TestCredentials < Command
			self.command = 'test-credentials'
			self.summary = 'Test given credentials against the server.'

			def self.options
				super.concat(space_options).sort
			end

			def run
				super
				importer.test_credentials
			end
		end
	end
end
