# frozen_string_literal: true

RSpec.describe DfE::Analytics::BigQueryApplyPolicyTags, type: :job do
  describe '.do' do
    context 'when delay_in_minutes is 0' do
      it 'enqueues the job immediately' do
        expect(described_class).to receive(:perform_later)
        described_class.do(delay_in_minutes: 0)
      end
    end

    context 'when delay_in_minutes is greater than 0' do
      it 'enqueues the job with a delay at the expected time' do
        frozen_time = Time.zone.local(2025, 8, 27, 12, 0, 0) # 27 Aug 2025, 12:00
        travel_to(frozen_time) do
          expect(described_class).to receive(:set).with(wait_until: frozen_time + 10.minutes).and_return(described_class)
          expect(described_class).to receive(:perform_later)

          described_class.do(delay_in_minutes: 10)
        end
      end
    end
  end

  describe '#perform' do
    subject(:job) { described_class.new }

    context 'when airbyte is disabled' do
      before do
        allow(DfE::Analytics).to receive(:airbyte_enabled?).and_return(false)
      end

      it 'logs a warning and does not call apply_policy_tags' do
        expect(Rails.logger).to receive(:warn).with(/airbyte is disabled/)
        expect(DfE::Analytics::BigQueryApi).not_to receive(:apply_policy_tags)

        job.perform
      end
    end

    context 'when airbyte is enabled' do
      let(:hidden_pii) { { users: %w[email name] } }
      let(:policy_tag) { 'projects/my-project/locations/eu/taxonomies/123/policyTags/abc' }

      before do
        allow(DfE::Analytics).to receive(:airbyte_enabled?).and_return(true)
        allow(DfE::Analytics).to receive(:hidden_pii).and_return(hidden_pii)

        config = double(:config, bigquery_hidden_policy_tag: policy_tag)
        allow(DfE::Analytics).to receive(:config).and_return(config)
      end

      it 'calls apply_policy_tags with hidden PII and policy tag' do
        expect(DfE::Analytics::BigQueryApi).to receive(:apply_policy_tags)
          .with(hidden_pii, policy_tag)

        job.perform
      end
    end
  end
end

# RSpec.describe DfE::Analytics::BigQueryApplyPolicyTags, type: :job do
# describe '.do' do
# context 'when delay_in_minutes is 0' do
# it 'enqueues the job immediately' do
# expect(described_class).to receive(:perform_later)
# described_class.do(delay_in_minutes: 0)
# end
# end

# context 'when delay_in_minutes is greater than 0' do
# it 'enqueues the job with a delay' do
# future_time = Time.zone.now + 5.minutes
# allow(Time.zone).to receive(:now).and_return(Time.zone.now)

# expect(described_class).to receive(:set).with(wait_until: future_time).and_return(described_class)
# expect(described_class).to receive(:perform_later)

# described_class.do(delay_in_minutes: 5)
# end
# end
# end

# describe '#perform' do
# subject(:job) { described_class.new }

# context 'when airbyte is disabled' do
# before do
# allow(DfE::Analytics).to receive(:airbyte_enabled?).and_return(false)
# end

# it 'logs a warning and does not call apply_policy_tags' do
# expect(Rails.logger).to receive(:warn).with(/airbyte is disabled/)
# expect(DfE::Analytics::BigQueryApi).not_to receive(:apply_policy_tags)

# job.perform
# end
# end

# context 'when airbyte is enabled' do
# let(:hidden_pii) { { users: ['email', 'name'] } }
# let(:policy_tag) { 'projects/my-project/locations/eu/taxonomies/123/policyTags/abc' }

# before do
# allow(DfE::Analytics).to receive(:airbyte_enabled?).and_return(true)
# allow(DfE::Analytics).to receive(:hidden_pii).and_return(hidden_pii)

# config = double(:config, bigquery_hidden_policy_tag: policy_tag)
# allow(DfE::Analytics).to receive(:config).and_return(config)
# end

# it 'calls apply_policy_tags with hidden PII and policy tag' do
# expect(DfE::Analytics::BigQueryApi).to receive(:apply_policy_tags)
# .with({ users: ['email', 'name'] }, 'projects/my-project/locations/eu/taxonomies/123/policyTags/abc')

# job.perform
# end
# end
# end
# end
