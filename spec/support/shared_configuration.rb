require './lib/configuration'

shared_context 'shared_configuration' do
  before do
    yaml_text = <<-EOF
          data_dir: spec/fixtures/import_files

          access_token: <ACCESS_TOKEN>
          organization_id: <ORGANIZATION_ID>
          space_id: ip17s12q0ek4
          default_locale: 'en-US'

          mapping_dir: spec/fixtures/settings/mapping.json
          contentful_structure_dir: spec/fixtures/settings/contentful_structure.json

          content_model_json: spec/fixtures/settings/contentful_model.json
          converted_model_dir: spec/fixtures/settings/contentful_structure_test.json
    EOF
    yaml = YAML.load(yaml_text)
    @config = Contentful::Configuration.new(yaml)
  end
end