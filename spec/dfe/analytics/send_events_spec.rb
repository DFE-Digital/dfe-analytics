# frozen_string_literal: true

RSpec.describe DfE::Analytics::SendEvents do
  include ActiveJob::TestHelper

  let(:event) do
    {
      environment: 'test',
      request_method: 'GET',
      request_path: '/provider/applications',
      namespace: 'provider_interface',
      user_id: 3456
    }
  end

  let(:events) { [event.as_json] }

  describe '#perform' do
    subject(:perform) { described_class.new.perform(events) }

    context 'when "log_only" is set' do
      before do
        allow(DfE::Analytics).to receive(:log_only?).and_return true
      end

      it 'does not go call bigquery apis' do
        expect(DfE::Analytics::BigQueryLegacyApi).not_to receive(:insert).with(events)
        perform
      end
    end

    describe 'logging events for event debug' do
      before do
        allow(DfE::Analytics).to receive(:event_debug_filters).and_return(event_debug_filters)
        allow(DfE::Analytics::BigQueryLegacyApi).to receive(:insert)
      end

      context 'when the event filter matches' do
        let(:event_debug_filters) do
          {
            event_filters: [
              {
                request_method: 'GET',
                request_path: '/provider/applications',
                namespace: 'provider_interface'
              }
            ]
          }
        end

        it 'logs the event' do
          expect(Rails.logger).to receive(:info).with("DfE::Analytics processing: #{event.as_json}")
          perform
        end
      end

      context 'when the event filter does not match' do
        let(:event_debug_filters) do
          {
            event_filters: [
              {
                request_method: 'POST',
                request_path: '/provider/applications',
                namespace: 'provider_interface'
              }
            ]
          }
        end

        it 'does not log the event' do
          expect(Rails.logger).not_to receive(:info)
          perform
        end
      end
    end

    describe 'Federated auth bigquery api' do
      it 'calls the expected federated auth api' do
        allow(DfE::Analytics.config).to receive(:azure_federated_auth).and_return(true)

        expect(DfE::Analytics::BigQueryApi).to receive(:insert).with(events)
        perform
      end
    end

    describe 'Legacy bigquery api (default)' do
      it 'calls the expected legacy api by default' do
        expect(DfE::Analytics::BigQueryLegacyApi).to receive(:insert).with(events)
        perform
      end
    end
  end

  describe 'retry behaviour' do
    before do
      # we don't want to define a permanent exception, just one for this test
      stub_const('DummyException', Class.new(StandardError))
    end

    it 'makes 5 attempts' do
      allow(DfE::Analytics).to receive(:log_only?).and_raise(DummyException)

      assert_performed_jobs 5 do
        described_class.perform_later([])
      rescue DummyException
        # the final exception won’t be caught
      end
    end
  end

  describe 'maintenance window scheduling' do
    let(:maintenance_window_start) { Time.zone.parse('25-02-2024 08:00') }
    let(:maintenance_window_end) { Time.zone.parse('25-02-2024 10:00') }
    let(:current_time_within_window) { Time.zone.parse('25-02-2024 09:00') }

    subject(:send_events) { described_class.do(events) }

    before do
      allow(DfE::Analytics).to receive(:within_maintenance_window?).and_return(true)
      allow(DfE::Analytics.config).to receive(:bigquery_maintenance_window).and_return('25-02-2024 08:00..25-02-2024 10:00')
      Timecop.freeze(current_time_within_window)
    end

    after do
      Timecop.return
    end

    context 'within the maintenance window' do
      it 'does not enqueue the events for asynchronous execution' do
        expect(DfE::Analytics::SendEvents).not_to receive(:perform_later).with(events)
        send_events
      end

      it 'does not execute the events synchronously' do
        expect(DfE::Analytics::SendEvents).not_to receive(:perform_now).with(events)
        send_events
      end

      it 'schedules the events for after the maintenance window' do
        elapsed_seconds = current_time_within_window - maintenance_window_start
        expected_wait_until = maintenance_window_end + elapsed_seconds

        expect(DfE::Analytics::SendEvents).to receive(:set).with(wait_until: expected_wait_until).and_call_original
        send_events
      end
    end

    context 'outside the mainenance window' do
      before do
        allow(DfE::Analytics).to receive(:within_maintenance_window?).and_return(false)
      end

      it 'enqueues the events for asynchronous execution' do
        allow(DfE::Analytics).to receive(:async?).and_return(true)
        expect(DfE::Analytics::SendEvents).to receive(:perform_later).with(events)
        send_events
      end

      it 'executes the events synchronously' do
        allow(DfE::Analytics).to receive(:async?).and_return(false)
        expect(DfE::Analytics::SendEvents).to receive(:perform_now).with(events)
        send_events
      end
    end
  end
end
