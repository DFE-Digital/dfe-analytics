RSpec.describe DfE::Analytics::EventSchema do
  describe '.as_json' do
    it 'returns the JSON schema as an object' do
      schema_on_disk = File.read("#{Gem.loaded_specs['dfe-analytics'].gem_dir}/config/event-schema.json")

      output = described_class.as_json

      expect(output).to be_present
      expect(output).to eq schema_on_disk
    end
  end
end
