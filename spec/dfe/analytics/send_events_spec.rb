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
  end
end
