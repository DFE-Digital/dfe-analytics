# frozen_string_literal: true

RSpec.describe DfE::Analytics::Services::ApplyAirbyteInternalTablesPolicyTags do
  let(:delay_in_minutes) { 5 }

  let(:config_double) do
    instance_double(
      'DfE::Analytics.config',
      airbyte_internal_dataset: 'internal_dataset',
      bigquery_hidden_policy_tag: 'projects/my-project/locations/eu/taxonomies/123/policyTags/xyz'
    )
  end

  let(:allowlist) do
    {
      academic_cycles: %w[id start_date],
      teachers: %w[id name email]
    }
  end

  let(:expected_internal_tables) do
    {
      'internal_dataset_raw__stream_academic_cycles' => '_airbyte_data',
      'internal_dataset_raw__stream_teachers' => '_airbyte_data'
    }
  end

  before do
    allow(DfE::Analytics).to receive(:config).and_return(config_double)
    allow(DfE::Analytics).to receive(:allowlist).and_return(allowlist)
    allow(DfE::Analytics::Jobs::BigQueryApplyPolicyTagsJob).to receive(:do)
  end

  describe '.call' do
    it 'calls BigQueryApplyPolicyTagsJob.do with internal dataset and correct table structure' do
      described_class.call(delay_in_minutes: delay_in_minutes)

      expect(DfE::Analytics::Jobs::BigQueryApplyPolicyTagsJob).to have_received(:do).with(
        delay_in_minutes: delay_in_minutes,
        dataset: 'internal_dataset',
        tables: expected_internal_tables,
        policy_tag: 'projects/my-project/locations/eu/taxonomies/123/policyTags/xyz'
      )
    end

    context 'when delay_in_minutes is 0' do
      let(:delay_in_minutes) { 0 }

      it 'calls the job with delay 0' do
        described_class.call(delay_in_minutes: delay_in_minutes)

        expect(DfE::Analytics::Jobs::BigQueryApplyPolicyTagsJob).to have_received(:do).with(
          delay_in_minutes: 0,
          dataset: 'internal_dataset',
          tables: expected_internal_tables,
          policy_tag: 'projects/my-project/locations/eu/taxonomies/123/policyTags/xyz'
        )
      end
    end
  end
end
