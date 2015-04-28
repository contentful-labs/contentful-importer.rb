require 'spec_helper'
require './lib/contentful/importer/publish_entries'

module Contentful
  module Importer
    describe ImportModel do
      before do
        setting_file = 'spec/fixtures/settings/settings.yml'
        @args = ["--configuration=#{setting_file}"]
      end

      it 'publish an entires' do
        vcr('publish_entries') do
          command = PublishEntries.parse(@args << 'publish-entries')
          command.run
        end
      end
    end
  end
end