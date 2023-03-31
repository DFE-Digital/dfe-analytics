# frozen_string_literal: true

RSpec.describe DfE::Analytics::Middleware::SendCachedPageRequestEvent do
  let(:app) { double('app') }

  subject { described_class.new(app) }

  describe '#call' do
    let(:env) { { 'PATH_INFO' => '/path/to/page', 'REQUEST_METHOD' => 'GET' } }
    let(:request) { instance_double(ActionDispatch::Request, request_id: '123') }
    let(:response) { instance_double(ActionDispatch::Response) }
    let(:event) { instance_double(DfE::Analytics::Event) }
    let(:is_cached) { false }

    before do
      allow(DfE::Analytics).to receive(:rack_page_cached?).with(env).and_return(is_cached)
      allow(ActionDispatch::Request).to receive(:new).with(env).and_return(request)
      allow(ActionDispatch::Response).to receive(:new).with(200, 'Content-Type' => 'text/html').and_return(response)
      allow(DfE::Analytics::Event).to receive(:new).and_return(event)

      allow(event).to receive(:with_type).with('web_request').and_return(event)
      allow(event).to receive(:with_request_details).with(request).and_return(event)
      allow(event).to receive(:with_response_details).with(response).and_return(event)
      allow(event).to receive(:with_request_uuid).with(request.request_id).and_return(event)
    end

    context 'when the page is cached' do
      let(:is_cached) { true }

      it 'sends a request event to BigQuery and calls next middleware' do
        expect(app).to receive(:call).with(env)
        expect(DfE::Analytics::SendEvents).to receive(:do).with([event.as_json])
        subject.call(env)
      end
    end

    context 'when the page is not cached' do
      let(:is_cached) { false }

      it 'does not send a request event to BigQuery and calls next middleware' do
        expect(app).to receive(:call).with(env)
        expect(DfE::Analytics::SendEvents).not_to receive(:do)
        subject.call(env)
      end
    end
  end
end
