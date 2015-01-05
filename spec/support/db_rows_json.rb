require 'multi_json'

def load_fixture(file, _as_json = false)
  JSON.parse(File.read(File.dirname(__FILE__) + "/../fixtures/#{file}.json")).with_indifferent_access
end

def load_json(file, _as_json = false)
  JSON.parse(File.read(File.dirname(__FILE__) + "/../fixtures/#{file}.json"))
end
