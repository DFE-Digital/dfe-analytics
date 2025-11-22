# frozen_string_literal: true

RSpec.describe DfE::Analytics::Jobs::BigQueryApplyPolicyTagsJob, type: :job do
  describe '.do' do
    let(:dataset) { 'airbyte_dataset' }
    let(:tables) { { users: %w[email name] } }
    let(:policy_tag) { 'projects/my-project/locations/eu/taxonomies/123/policyTags/abc' }

    context 'when delay_in_minutes is 0' do
      it 'enqueues the job immediately' do
        expect(described_class).to receive(:perform_later).with(dataset, tables, policy_tag)
        described_class.do(delay_in_minutes: 0, dataset: dataset, tables: tables, policy_tag: policy_tag)
      end
    end

    context 'when delay_in_minutes is greater than 0' do
      it 'enqueues the job with a delay at the expected time' do
        frozen_time = Time.zone.local(2025, 8, 27, 12, 0, 0)
        travel_to(frozen_time) do
          expect(described_class)
            .to receive(:set)
            .with(wait_until: frozen_time + 10.minutes)
            .and_return(described_class)
          expect(described_class)
            .to receive(:perform_later)
            .with(dataset, tables, policy_tag)

          described_class.do(delay_in_minutes: 10, dataset: dataset, tables: tables, policy_tag: policy_tag)
        end
      end
    end
  end

  describe '#perform' do
    subject(:job) { described_class.new }

    let(:dataset) { 'airbyte_dataset' }
    let(:tables) { { users: %w[email name] } }
    let(:policy_tag) { 'projects/my-project/locations/eu/taxonomies/123/policyTags/abc' }

    context 'when airbyte is disabled' do
      before do
        allow(DfE::Analytics).to receive(:airbyte_enabled?).and_return(false)
      end

      it 'logs a warning and does not call apply_policy_tags' do
        expect(Rails.logger).to receive(:warn).with(/airbyte is disabled/)
        expect(DfE::Analytics::BigQueryApi).not_to receive(:apply_policy_tags)

        job.perform(dataset, tables, policy_tag)
      end
    end

    context 'when airbyte is enabled' do
      before do
        allow(DfE::Analytics).to receive(:airbyte_enabled?).and_return(true)
      end

      it 'calls apply_policy_tags with dataset, tables, and policy_tag' do
        expect(DfE::Analytics::BigQueryApi)
          .to receive(:apply_policy_tags)
          .with(dataset, tables, policy_tag)

        job.perform(dataset, tables, policy_tag)
      end
    end
  end
end
