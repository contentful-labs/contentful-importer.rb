require 'spec_helper'
require './lib/contentful/importer/test_credentials'

module Contentful
  module Importer
    describe TestCredentials do
      before do
        setting_file = 'spec/fixtures/settings/settings.yml'
        @args = ["--configuration=#{setting_file}", 'test-credentials']
      end

      it 'when valid' do
        vcr('valid_credentials') do
          expect_any_instance_of(Logger).to receive(:info).with('Contentful Management API credentials: OK')
          TestCredentials.parse(@args).run
        end
      end

      it 'when invalid' do
        vcr('invalid_credentials') do
          expect_any_instance_of(Logger).to receive(:info).with('Contentful Management API credentials: INVALID (check README)')
          TestCredentials.parse(@args).run
        end
      end
    end
  end
end