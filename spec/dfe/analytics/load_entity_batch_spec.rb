RSpec.describe DfE::Analytics::LoadEntityBatch do
  include ActiveJob::TestHelper

  with_model :Candidate do
    table do |t|
      t.string :email_address
    end
  end

  before do
    allow(DfE::Analytics::SendEvents).to receive(:perform_later)
  end

  around do |ex|
    perform_enqueued_jobs do
      ex.run
    end
  end

  it 'accepts its first arg as a String to support Rails < 6.1' do
    # Rails 6.1rc1 added support for deserializing Class and Module params
    c = Candidate.create(email_address: 'foo@example.com')

    described_class.perform_later('Candidate', [c.id], 1)

    expect(DfE::Analytics::SendEvents).to have_received(:perform_later).once
  end

  if Gem::Version.new(Rails.version) >= Gem::Version.new('6.1')
    it 'accepts its first arg as a Class' do
      # backwards compatability with existing enqueued jobs
      c = Candidate.create(email_address: 'foo@example.com')

      described_class.perform_later(Candidate, [c.id], 1)

      expect(DfE::Analytics::SendEvents).to have_received(:perform_later).once
    end
  end
end
