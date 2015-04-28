require 'spec_helper'
require './lib/contentful/importer/import_assets'

module Contentful
  module Importer
    describe ImportAssets do
      before do
        setting_file = 'spec/fixtures/settings/settings.yml'
        @args = ["--configuration=#{setting_file}"]
      end

      it 'import an assets to Contentful' do
        vcr('import_assets') do
          command = ImportAssets.parse(@args << 'import-assets')
          command.run
        end
      end
    end
  end
end