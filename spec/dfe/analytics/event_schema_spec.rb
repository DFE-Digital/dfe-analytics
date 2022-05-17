RSpec.describe DfE::Analytics::EventSchema do
  describe '.as_json' do
    it 'returns the JSON schema as an object' do
      schema_on_disk = File.read("#{Gem.loaded_specs['dfe-analytics'].gem_dir}/config/event-schema.json")

      output = described_class.as_json

      expect(output).to be_present
      expect(output).to eq schema_on_disk
    end
  end

  describe '.as_bigquery_schema' do
    it 'transforms the JSON schema into a BQ schema' do
      bq_schema_on_disk = File.read('spec/examples/bigquery_schema.json')

      output = JSON.parse(described_class.as_bigquery_schema)

      expect(output).to be_present
      expect(output).to match_array JSON.parse(bq_schema_on_disk)
    end
  end
end
