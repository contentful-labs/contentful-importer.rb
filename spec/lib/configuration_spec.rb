require 'spec_helper'
require './lib/configuration'

module Contentful
  describe Configuration do

    include_context 'shared_configuration'

    it 'initialize' do
      expect(@config.data_dir).to eq 'spec/fixtures/import_files'
      expect(@config.collections_dir).to eq 'spec/fixtures/import_files/collections'
      expect(@config.assets_dir).to eq 'spec/fixtures/import_files/assets'
      expect(@config.entries_dir).to eq 'spec/fixtures/import_files/entries'
      expect(@config.log_files_dir).to eq 'spec/fixtures/import_files/logs'
      expect(@config.threads_dir).to eq 'spec/fixtures/import_files/threads'
      expect(@config.imported_entries).to be_empty
      expect(@config.published_entries).to be_empty
      expect(@config.published_assets).to be_empty
      expect(@config.converted_model_dir).to eq 'spec/fixtures/settings/contentful_structure_test.json'
      expect(@config.contentful_structure).to be_a Hash
      expect(@config.space_id).to eq 'ip17s12q0ek4'
      expect(@config.content_types).to eq 'spec/fixtures/settings/contentful_model.json'
    end
  end
end