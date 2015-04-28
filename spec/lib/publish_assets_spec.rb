require 'spec_helper'
require './lib/contentful/importer/publish_assets'

module Contentful
  module Importer
    describe PublishAssets do
      before do
        setting_file = 'spec/fixtures/settings/settings.yml'
        @args = ["--configuration=#{setting_file}"]
      end

      it 'publish an assets' do
        vcr('publish_asset') do
          expect_any_instance_of(ParallelImporter).to receive(:publish_status).exactly(4).times
          expect_any_instance_of(ParallelImporter).to receive(:create_log_file).with('success_published_assets')
          
          command = PublishAssets.parse(@args + ['publish-assets', '--threads=1'])
          command.run
        end
      end
    end
  end
end