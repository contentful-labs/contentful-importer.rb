require 'spec_helper'
require './lib/contentful/importer/import_entries'

module Contentful
  module Importer
    describe ImportEntries do
      before do
        setting_file = 'spec/fixtures/settings/settings.yml'
        @args = ["--configuration=#{setting_file}"]
      end

      it 'import an entires to Contentful with two Threads' do
        vcr('import_entries') do
          allow(FileUtils).to receive(:rm_r)
          command = ImportEntries.parse(@args + ['import-entries', '--threads=2'])
          import = command.run
          expect(import).to be_a Array
          expect(import.count).to eq 2
        end
      end
    end
  end
end