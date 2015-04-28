require 'spec_helper'
require './lib/contentful/importer/import_model'

module Contentful
  module Importer
    describe ImportModel do
      before do
        setting_file = 'spec/fixtures/settings/settings.yml'
        @args = ["--configuration=#{setting_file}"]
      end
      
      it 'convert contentful model to contentful structure' do
        allow_any_instance_of(ParallelImporter).to receive(:create_contentful_model)

        command = ImportModel.parse(@args << 'import-content-model')
        command.run

        contentful_structure = load_fixture('settings/contentful_structure_test')
        expect(contentful_structure.count).to eq 4
        expect(contentful_structure['Jobs']).to include(id: '4L1bg4WQ5aWQMiE82ouag', name: 'Jobs', displayField: 'title', description: nil)
        expect(contentful_structure['Jobs']['fields'].count).to eq 4
        expect(contentful_structure['Jobs']['fields']['Image']).to include(id: 'image', type: 'Asset', link: 'Link')
        expect(contentful_structure['Jobs']['fields']['Creator']).to include(id: 'creator', type: 'Entry', link: 'Link')
      end

      it 'create content type json files from contentful structure' do
        allow_any_instance_of(ParallelImporter).to receive(:create_contentful_model)

        command = ImportModel.parse(@args << 'import-content-model')
        command.run

        expect(Dir.glob('spec/fixtures/import_files/collections/*').count).to eq 4
        content_types_files = %w(comment.json job_skills.json jobs.json profile.json user.json)
        Dir.glob('spec/fixtures/import_files/collections/*') do |directory_name|
          expect(content_types_files.include?(File.basename(directory_name))).to be true
        end
        job_skills = load_fixture('import_files/collections/job_skills')
        expect(job_skills).to include(id: '2soCP557HGKoOOK0SqmMOm', name: 'Job Skills', displayField: 'name')
        expect(job_skills['fields'].count).to eq 1
        expect(job_skills['fields'].first).to include(id: 'name', name: 'Name', type: 'Text')

        jobs = load_fixture('import_files/collections/jobs')
        expect(jobs).to include(id: '4L1bg4WQ5aWQMiE82ouag', name: 'Jobs', displayField: 'title')
        expect(jobs['fields'].count).to eq 5
        expect(jobs['fields'].last).to include(id: 'skills', name: 'Skills', type: 'Array', link_type: 'Entry', link: 'Link')

        profile = load_fixture('import_files/collections/profile')
        expect(profile).to include(id: '4WFZh4MwC4Mc0EQWAeOY8A', name: 'Profile', displayField: nil)
        expect(profile['fields'].count).to eq 2
        expect(profile['fields'].first).to include(id: 'nickname', name: 'Nickname', type: 'Text')

        user = load_fixture('import_files/collections/user')
        expect(user).to include(id: '1TVvxCqoRq0qUYAOQuOqys', name: 'User', displayField: 'first_name')
        expect(user['fields'].first).to include(id: 'first_name', name: 'First_name', type: 'Text')
      end

      it 'create content type json files from contentful structure' do
        vcr('import_content_types') do
          command = ImportModel.parse(@args + ['import-content-model', '--space_id=space_id'])
          command.run
        end
      end

      it 'validate JSON schema' do
        allow_any_instance_of(ParallelImporter).to receive(:create_contentful_model)
        
        command = ImportModel.parse(@args << 'import-content-model')
        expect { command.run }.not_to raise_error
      end
    end
  end
end