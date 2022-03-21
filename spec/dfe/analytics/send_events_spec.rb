# frozen_string_literal: true

RSpec.describe DfE::Analytics::SendEvents do
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
  end
end
