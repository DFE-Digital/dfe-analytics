module DfE
  module Analytics
    class EventSchema
      def self.as_json
        path = "#{Gem.loaded_specs['dfe-analytics'].gem_dir}/config/event-schema.json"
        File.read(path)
      end
    end
  end
end
