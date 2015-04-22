require 'spec_helper'
require './lib/contentful/importer/parallel_importer'
require './lib/contentful/importer/configuration'

module Contentful
  module Importer
    describe ParallelImporter do

      include_context 'shared_configuration'

      before do
        @importer = ParallelImporter.new(@config)
      end


      it 'number of threads' do
        number = @importer.number_of_threads
        expect(number).to eq 2
      end

      it 'create_asset_file' do
        file = @importer.create_asset_file('title', {'url' => 'www.example.com/photo.png'})
        expect(file).to be_a Contentful::Management::File
      end

      it 'gets asset content type from params' do
        file = @importer.create_asset_file('title', {'url' => 'www.example.com/image.jpg?withoutextension', 'contentType' => 'image/jpeg'})
        expect(file.properties[:contentType]).to eq'image/jpeg'
      end

      it 'gets asset content type from params' do
        file = @importer.create_asset_file('title', {'url' => 'www.example.com/image.jpg'})
        expect(file.properties[:contentType]).to eq'image/jpeg'
      end

      it 'get_id' do
        id = @importer.send(:get_id, {'id' => 'name.png'})
        expect(id).to eq 'name.png'
      end

      context 'asset_status' do
        it 'successfully imported' do
          allow(CSV).to receive(:open).with('spec/fixtures/import_files/logs/success_assets.csv', 'a')
          asset_file = Contentful::Management::Asset.new
          asset_file.id = 'test_id'
          expect_any_instance_of(Contentful::Management::Asset).to receive(:process_file)
          @importer.asset_status(asset_file, {'url' => 'www.example.com/photo.png'})
        end
      end

      it 'publish an entry' do
        vcr('publish_an_entry') do
          expect_any_instance_of(ParallelImporter).to receive(:publish_status).with(Contentful::Management::Entry,
                                                                                                'comment_5',
                                                                                                'published_entries')
          @importer.publish_entry('comment_5')
        end
      end

      it 'import_entry' do
        vcr('import_entry') do
          expect_any_instance_of(ParallelImporter).to receive(:import_status).with(Contentful::Management::Entry, './spec/fixtures/import_files/entries/job_skills/job_skills_1.json', 'success_thread_0')
          expect(Contentful::Management::Entry.find('ip17s12q0ek4', 'job_skills_1')).to be_a Contentful::Management::NotFound
          @importer.send(:import_entry, './spec/fixtures/import_files/entries/job_skills/job_skills_1.json', 'ip17s12q0ek4', '2soCP557HGKoOOK0SqmMOm', 'success_thread_0')
          entry = Contentful::Management::Entry.find('ip17s12q0ek4', 'job_skills_1')
          expect(entry).to be_a Contentful::Management::Entry
          expect(entry.id).to eq 'job_skills_1'
          expect(entry.name).to eq 'Commercial awareness'
        end
      end

      context 'import_status' do
        it 'successfully imported' do
          allow(CSV).to receive(:open).with('spec/fixtures/import_files/logs/success_thread_0.csv', 'a')
          allow(File).to receive(:basename).with('file_path')
          entry = Contentful::Management::Entry.new
          @importer.send(:import_status, entry, 'file_path', 'success_thread_0')
        end
      end

      it 'create space' do
        vcr('create_space') do
          space = @importer.send(:create_space, 'rspec_test_space')
          expect(space).to be_a Contentful::Management::Space
          expect(space.name).to eq 'rspec_test_space'
        end
      end

      it 'create entry' do
        vcr('create_entry') do
          entry = @importer.send(:create_entry, {'id' => 'entry_id'}, 'ip17s12q0ek4', '6H6pGAV1PUsuoAW26Iu48W')
          expect(entry).to be_a Contentful::Management::Entry
          expect(entry.id).to eq 'entry_id'
        end
      end

      it 'create asset' do
        vcr('create_asset') do
          asset = @importer.send(:create_asset, 'ip17s12q0ek4', {'id' => 'asset_id'})
          expect(asset).to be_a Contentful::Management::Asset
          expect(asset.id).to eq 'asset_id'
        end
      end

      it 'create location file' do
        file = @importer.send(:create_location_file, {'lat' => 'lat_v', 'lng' => 'lng_v'})
        expect(file).to be_a Contentful::Management::Location
      end

      context 'validate_params' do
        it 'Array type' do
          result = @importer.send(:validate_param, [])
          expect(result).to be true
        end
        it 'Other type' do
          result = @importer.send(:validate_param, 'value')
          expect(result).to be false
        end
      end

      context 'create_entry_parameters' do
        it 'Hash' do
          expect_any_instance_of(ParallelImporter).to receive(:validate_param) { true }
          expect_any_instance_of(ParallelImporter).to receive(:parse_attributes_from_hash).with({'k' => 'v'}, 'space_id', 'content_type_id')
          @importer.send(:create_entry_parameters, 'content_type_id', {'Hash' => {'k' => 'v'}}, 'space_id')
        end
        it 'Array' do
          expect_any_instance_of(ParallelImporter).to receive(:validate_param) { true }
          expect_any_instance_of(ParallelImporter).to receive(:parse_attributes_from_array).with(['Value'], 'space_id', 'content_type_id')
          @importer.send(:create_entry_parameters, 'content_type_id', {'Array' => ['Value']}, 'space_id')
        end
        it 'String' do
          expect_any_instance_of(ParallelImporter).to receive(:validate_param) { true }
          @importer.send(:create_entry_parameters, 'content_type_id', {'key' => 'value'}, 'space_id')
        end
      end

      context 'parse_attributes_from_hash' do
        it 'Location' do
          expect_any_instance_of(ParallelImporter).to receive(:create_location_file).with({'type' => 'Location'})
          @importer.send(:parse_attributes_from_hash, {'type' => 'Location'}, 'space_id', 'content_type_id')
        end
        it 'File' do
          expect_any_instance_of(ParallelImporter).to receive(:create_asset).with('space_id', {'type' => 'File'})
          @importer.send(:parse_attributes_from_hash, {'type' => 'File'}, 'space_id', 'content_type_id')
        end
        it 'Entry' do
          expect_any_instance_of(ParallelImporter).to receive(:create_entry).with({'type' => 'Entry'}, 'space_id', 'content_type_id')
          @importer.send(:parse_attributes_from_hash, {'type' => 'Entry'}, 'space_id', 'content_type_id')
        end
        it 'Entry' do
          params = @importer.send(:parse_attributes_from_hash, {'some' => 'params'}, 'space_id', 'content_type_id')
          expect(params).to include('some' => 'params')
        end
      end

      context 'parse_attributes_from_array' do
        it 'File' do
          expect_any_instance_of(ParallelImporter).to receive(:create_asset).with('space_id', {'type' => 'File'})
          @importer.send(:parse_attributes_from_array, [{'type' => 'File'}], 'space_id', 'content_type_id')
        end
        it 'Entry' do
          expect_any_instance_of(ParallelImporter).to receive(:create_entry).with({'type' => 'Entry'}, 'space_id', 'content_type_id')
          @importer.send(:parse_attributes_from_array, [{'type' => 'Entry'}], 'space_id', 'content_type_id')
        end
        it 'Entry' do
          params = @importer.send(:parse_attributes_from_array, [{'some' => 'params'}], 'space_id', 'content_type_id')
          expect(params).to include('some' => 'params')
        end
      end
    end
  end
end