# frozen_string_literal: true

RSpec.describe DfE::Analytics::SendEvents do
  include ActiveJob::TestHelper

  describe '#perform' do
    let(:event) do
      {
        environment: 'test',
        request_method: 'GET',
        request_path: '/provider/applications',
        namespace: 'provider_interface',
        user_id: 3456
      }
    end

    context 'when the request is successful' do
      it 'sends the events JSON to Bigquery' do
        request = stub_analytics_event_submission

        DfE::Analytics::Testing.webmock! do
          described_class.new.perform([event.as_json])

          expect(request.with do |req|
            body = JSON.parse(req.body)
            payload = body['rows'].first['json']
            expect(payload.except('occurred_at', 'request_uuid')).to match(a_hash_including(event.deep_stringify_keys))
          end).to have_been_made
        end
      end

      it 'does not log the request when event_debug disabled' do
        stub_analytics_event_submission

        expect(Rails.logger).not_to receive(:info)

        DfE::Analytics::Testing.webmock! do
          described_class.new.perform([event.as_json])
        end
      end
    end

    context 'when the request is not successful' do
      before { stub_analytics_event_submission_with_insert_errors }

      subject(:perform) do
        DfE::Analytics::Testing.webmock! do
          described_class.new.perform([event.as_json])
        end
      end

      it 'raises an exception' do
        expect { perform }.to raise_error(DfE::Analytics::SendEventsError, /An error./)
      end

      it 'contains the insert errors' do
        perform
      rescue DfE::Analytics::SendEventsError => e
        expect(e.message).to_not be_empty
      end

      it 'logs the error message' do
        expect(Rails.logger).to receive(:error).with(/DfE::Analytics BigQuery API insert error for 1 event\(s\):/)

        perform
      rescue DfE::Analytics::SendEventsError
        nil
      end
    end

    context 'when "log_only" is set' do
      before do
        allow(DfE::Analytics).to receive(:log_only?).and_return true
      end

      it 'does not go out to the network' do
        request = stub_analytics_event_submission

        DfE::Analytics::Testing.webmock! do
          described_class.new.perform([event.as_json])
          expect(request).not_to have_been_made
        end
      end
    end

    describe 'logging events for event debug' do
      before do
        stub_analytics_event_submission

        allow(DfE::Analytics).to receive(:event_debug_filters).and_return(event_debug_filters)
      end

      subject(:perform) do
        DfE::Analytics::Testing.webmock! do
          described_class.new.perform([event.as_json])
        end
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

    context 'when using fake testing mode' do
      it 'does not go out to the network' do
        request = stub_analytics_event_submission

        DfE::Analytics::Testing.fake! do
          described_class.new.perform([event.as_json])
          expect(request).not_to have_been_made
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
      let(:events) { [event] }
      let(:maintenance_window_start) { Time.zone.parse('25-02-2024 08:00') }
      let(:maintenance_window_end) { Time.zone.parse('25-02-2024 10:00') }
      let(:current_time_within_window) { Time.zone.parse('25-02-2024 09:00') }

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
          DfE::Analytics::SendEvents.do(events)
        end

        it 'does not execute the events synchronously' do
          expect(DfE::Analytics::SendEvents).not_to receive(:perform_now).with(events)
          DfE::Analytics::SendEvents.do(events)
        end

        it 'schedules the events for after the maintenance window' do
          elapsed_seconds = current_time_within_window - maintenance_window_start
          expected_wait_until = maintenance_window_end + elapsed_seconds

          expect(DfE::Analytics::SendEvents).to receive(:set).with(wait_until: expected_wait_until).and_call_original
          DfE::Analytics::SendEvents.do(events)
        end
      end

      context 'outside the mainenance window' do
        before do
          allow(DfE::Analytics).to receive(:within_maintenance_window?).and_return(false)
        end

        it 'enqueues the events for asynchronous execution' do
          allow(DfE::Analytics).to receive(:async?).and_return(true)
          expect(DfE::Analytics::SendEvents).to receive(:perform_later).with(events)
          DfE::Analytics::SendEvents.do(events)
        end

        it 'executes the events synchronously' do
          allow(DfE::Analytics).to receive(:async?).and_return(false)
          expect(DfE::Analytics::SendEvents).to receive(:perform_now).with(events)
          DfE::Analytics::SendEvents.do(events)
        end
      end
    end
  end
end
