RSpec.describe DfE::Analytics::LoadEntityBatch do
  include ActiveJob::TestHelper

  with_model :Candidate do
    table do |t|
      t.string :email_address
      t.string :dob
    end
  end

  before do
    allow(DfE::Analytics::SendEvents).to receive(:perform_now)

    allow(DfE::Analytics).to receive(:allowlist).and_return({
      Candidate.table_name.to_sym => %w[email_address]
    })
  end

  describe '#perform' do
    entity_tag = Time.now.strftime('%Y%m%d%H%M%S')
    let(:model_class) { 'Candidate' }
    before { Timecop.freeze(entity_tag) }
    after { Timecop.return }

    it 'adds an event_tag to all events for a given import in the format YYYYMMDDHHMMSS' do
      c = Candidate.create(email_address: '12345678910')
      c2 = Candidate.create(email_address: '12345678910')
      described_class.new.perform(model_class, [c.id, c2.id], entity_tag)

      expect(DfE::Analytics::SendEvents).to have_received(:perform_now) do |events|
        expect(events.first['event_type']).to eq('import_entity')
        expect(events.first['event_tags']).to eq([entity_tag])
      end
    end

    it 'splits a batch when the batch is too big' do
      perform_enqueued_jobs do
        c = Candidate.create(email_address: '12345678910')
        c2 = Candidate.create(email_address: '12345678910')
        stub_const('DfE::Analytics::LoadEntityBatch::BQ_BATCH_MAX_BYTES', 300)

        described_class.perform_now('Candidate', [c.id, c2.id], entity_tag)

        expect(DfE::Analytics::SendEvents).to have_received(:perform_now).twice
      end
    end

    it 'doesn’t split a batch unless it has to' do
      c = Candidate.create(email_address: '12345678910')
      c2 = Candidate.create(email_address: '12345678910')
      stub_const('DfE::Analytics::LoadEntityBatch::BQ_BATCH_MAX_BYTES', 550)

      described_class.perform_now('Candidate', [c.id, c2.id], entity_tag)

      expect(DfE::Analytics::SendEvents).to have_received(:perform_now).once
    end

    it 'accepts its first arg as a String to support Rails < 6.1' do
      # Rails 6.1rc1 added support for deserializing Class and Module params
      c = Candidate.create(email_address: 'foo@example.com')

      described_class.perform_now('Candidate', [c.id], entity_tag)

      expect(DfE::Analytics::SendEvents).to have_received(:perform_now).once
    end

    if Gem::Version.new(Rails.version) >= Gem::Version.new('6.1')
      it 'accepts its first arg as a Class' do
        # backwards compatability with existing enqueued jobs
        c = Candidate.create(email_address: 'foo@example.com')

        described_class.perform_now(Candidate, [c.id], entity_tag)

        expect(DfE::Analytics::SendEvents).to have_received(:perform_now).once
      end
    end

    context 'when both allowed data and hidden data is present' do
      before do
        allow(DfE::Analytics).to receive(:allowlist).and_return({
          Candidate.table_name.to_sym => %w[email_address dob]
        })

        allow(DfE::Analytics).to receive(:hidden_pii).and_return({
          Candidate.table_name.to_sym => %w[dob]
        })
      end

      it 'includes both allowed and hidden data in the event when present' do
        candidate = Candidate.create(email_address: 'test@example.com', dob: '20062000')

        described_class.new.perform(model_class, [candidate.id], entity_tag)

        expect(DfE::Analytics::SendEvents).to have_received(:perform_now) do |events|
          expect(events.first['data']).not_to be_empty
          expect(events.first['hidden_data']).not_to be_empty
        end
      end

      it 'splits a batch when the batch is too big, including hidden data' do
        perform_enqueued_jobs do
          c = Candidate.create(email_address: '12345678910', dob: '12072000')
          c2 = Candidate.create(email_address: '12345678910', dob: '12072000')

          stub_const('DfE::Analytics::LoadEntityBatch::BQ_BATCH_MAX_BYTES', 300)

          described_class.perform_now('Candidate', [c.id, c2.id], entity_tag)

          expect(DfE::Analytics::SendEvents).to have_received(:perform_now).twice
        end
      end

      it 'does not split a batch if the payload size is below the threshold' do
        perform_enqueued_jobs do
          c = Candidate.create(email_address: '12345678910')
          c2 = Candidate.create(email_address: '12345678910')
          stub_const('DfE::Analytics::LoadEntityBatch::BQ_BATCH_MAX_BYTES', 1000)

          described_class.perform_now('Candidate', [c.id, c2.id], entity_tag)

          expect(DfE::Analytics::SendEvents).to have_received(:perform_now).once
        end
      end
    end
  end
end
