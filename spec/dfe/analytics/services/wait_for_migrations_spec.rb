# frozen_string_literal: true

RSpec.describe DfE::Analytics::Services::WaitForMigrations do
  subject(:service) { described_class.new }

  before do
    # Prevent real sleeping
    allow(service).to receive(:sleep)
  end

  context 'when there are no pending migrations' do
    before do
      allow(ActiveRecord::Migration).to receive(:check_all_pending!).and_return(nil)
    end

    it 'returns immediately' do
      expect(service.call).to be_nil
      expect(service).to have_received(:sleep).once
    end
  end

  context 'when migrations clear after a few loops' do
    before do
      calls = 0
      allow(ActiveRecord::Migration).to receive(:check_all_pending!) do
        calls += 1
        raise ActiveRecord::PendingMigrationError if calls < 3

        nil
      end
    end

    it 'loops until migrations clear' do
      expect(service.call).to be_nil
      # It should sleep twice before migrations clear
      expect(service).to have_received(:sleep).exactly(3).times
    end
  end

  context 'when checking migration status raises a non-pending error' do
    before do
      allow(ActiveRecord::Migration).to receive(:check_all_pending!)
        .and_raise(StandardError.new('DB offline'))
      allow(Rails.logger).to receive(:error)
    end

    it 'logs and wraps the error' do
      expect do
        service.call
      end.to raise_error(described_class::Error, /Could not check migration status/)
    end
  end

  context 'when timeout is reached' do
    before do
      # Stub the private method so we don't hit real migration loading
      allow(service).to receive(:pending_migrations?).and_return(true)

      # Fake time progressing 30s per loop
      fake_times = (0..700).step(30).map { |sec| Time.at(sec) }
      allow(Time).to receive(:now).and_return(*fake_times)

      # Prevent real sleep
      allow(service).to receive(:sleep)
    end

    it 'raises a timeout error' do
      expect do
        service.call
      end.to raise_error(described_class::Error, /Timed out/)
    end
  end
end
