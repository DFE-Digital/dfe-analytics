module DfE
  module Analytics
    class EventSchema
      def self.as_json
        path = "#{Gem.loaded_specs['dfe-analytics'].gem_dir}/config/event-schema.json"
        File.read(path)
      end

      def self.as_bigquery_schema
        schema = JSON.parse(as_json)
        required_fields = schema['required']

        properties = schema['properties']

        schema = properties.keys.reduce([]) do |bq_schema, json_schema_entry_name|
          json_schema_entry = properties[json_schema_entry_name]
          bigquery_field_type = resolve_bigquery_type(json_schema_entry)

          bigquery_schema_entry = {
            'mode' => resolve_bigquery_mode(json_schema_entry_name, json_schema_entry, required_fields),
            'name' => json_schema_entry_name,
            'type' => bigquery_field_type
          }

          if bigquery_field_type == 'RECORD'
            bigquery_schema_entry['fields'] = [
              {
                'mode' => 'REQUIRED',
                'name' => 'key',
                'type' => 'STRING'
              },
              {
                'mode' => 'REPEATED',
                'name' => 'value',
                'type' => 'STRING'
              }
            ]
          end

          bq_schema << bigquery_schema_entry
          bq_schema
        end

        schema.to_json
      end

      def self.resolve_bigquery_mode(json_schema_entry_name, json_schema_entry, required_fields)
        if required_fields.include?(json_schema_entry_name)
          'REQUIRED'
        elsif json_schema_entry['type'] == 'array'
          'REPEATED'
        else
          'NULLABLE'
        end
      end

      def self.resolve_bigquery_type(json_schema_entry)
        json_type = json_schema_entry['type']
        json_format = json_schema_entry['format']

        if json_type == 'array'
          'RECORD'
        elsif json_type == 'string' && json_format == 'date-time'
          'TIMESTAMP'
        elsif json_type == 'string'
          'STRING'
        elsif json_type == 'integer'
          'INTEGER'
        end
      end
    end
  end
end
