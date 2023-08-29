# frozen_string_literal: true

RSpec.describe 'Inclusion in the context of single table inheritance' do
  with_model :Parent do
    table do |t|
      t.string :type
    end
  end

  before do
    allow(DfE::Analytics).to receive(:enabled?).and_return(true)
    allow(DfE::Analytics).to receive(:allowlist).and_return({ Parent.table_name.to_sym => %w[type] })

    stub_const('Child', Class.new(Parent))
    stub_const('Sibling', Class.new(Parent))

    # autogenerate a compliant blocklist
    allow(DfE::Analytics).to receive(:blocklist).and_return(DfE::Analytics::Fields.generate_blocklist)
  end

  it 'correctly includes callbacks for each member of the STI party' do
    DfE::Analytics.initialize!
    expect(Parent).to include(DfE::Analytics::Entities)
    expect(Child).to include(DfE::Analytics::Entities)
    expect(Sibling).to include(DfE::Analytics::Entities)
  end

  it 'does not log a deprecation warning' do
    expect(Rails.logger).not_to receive(:info).with(/DEPRECATION WARNING/)
    DfE::Analytics.initialize!
  end
end
