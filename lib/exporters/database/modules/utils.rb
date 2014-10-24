module Contentful
  module Exporter
    module Database
      module Utils

        def write_json_to_file(path, data)
          File.open(path, 'w') do |file|
            file.write(JSON.pretty_generate(data))
          end
        end

      end
    end
  end
end

