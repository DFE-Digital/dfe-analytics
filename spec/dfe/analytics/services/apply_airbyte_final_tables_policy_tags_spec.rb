# frozen_string_literal: true

RSpec.describe DfE::Analytics::Services::ApplyAirbyteFinalTablesPolicyTags do
  let(:delay_in_minutes) { 10 }

  let(:config_double) do
    instance_double(
      'DfE::Analytics.config',
      bigquery_airbyte_dataset: 'airbyte_dataset',
      bigquery_hidden_policy_tag: 'projects/my-project/locations/eu/taxonomies/123/policyTags/abc'
    )
  end

  let(:hidden_pii) do
    { users: %w[email name], schools: %w[address postcode] }
  end

  before do
    allow(DfE::Analytics).to receive(:config).and_return(config_double)
    allow(DfE::Analytics).to receive(:hidden_pii).and_return(hidden_pii)
    allow(DfE::Analytics::BigQueryApplyPolicyTagsJob).to receive(:do)
  end

  describe '.call' do
    it 'calls BigQueryApplyPolicyTagsJob.do with correct arguments' do
      described_class.call(delay_in_minutes:)

      expect(DfE::Analytics::BigQueryApplyPolicyTagsJob).to have_received(:do).with(
        delay_in_minutes: delay_in_minutes,
        dataset: 'airbyte_dataset',
        tables: hidden_pii,
        policy_tag: 'projects/my-project/locations/eu/taxonomies/123/policyTags/abc'
      )
    end

    context 'when delay_in_minutes is 0' do
      let(:delay_in_minutes) { 0 }

      it 'passes delay_in_minutes: 0 to the job' do
        described_class.call(delay_in_minutes:)

        expect(DfE::Analytics::BigQueryApplyPolicyTagsJob).to have_received(:do).with(
          delay_in_minutes: 0,
          dataset: 'airbyte_dataset',
          tables: hidden_pii,
          policy_tag: 'projects/my-project/locations/eu/taxonomies/123/policyTags/abc'
        )
      end
    end
  end
end
