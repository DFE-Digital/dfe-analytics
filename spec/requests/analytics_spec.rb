RSpec.describe 'Analytics flow', type: :request do
  before do
    model = Class.new(Candidate) do
      include DfE::Analytics::Entities
    end

    stub_const('Candidate', model)

    controller = Class.new(ApplicationController) do
      include DfE::Analytics::Requests

      def index
        render plain: 'Index page'
      end

      def create
        Candidate.create(
          email_address: 'a@b.com',
          first_name: 'Mr',
          last_name: 'Knox'
        )

        render plain: ''
      end
    end

    stub_const('TestController', controller)

    allow(DfE::Analytics).to receive(:enabled?).and_return(true)

    allow(DfE::Analytics).to receive(:allowlist).and_return({
      candidates: %i[id email_address]
    })
  end

  around do |ex|
    Rails.application.routes.draw do
      post '/example/create' => 'test#create'
      get '/example/' => 'test#index'
    end

    DfE::Analytics::Testing.webmock! do
      ex.run
    end

  ensure
    Rails.application.routes_reloader.reload!
  end

  it 'works end-to-end' do
    request_event = { environment: 'test',
                      event_type: 'web_request',
                      request_method: 'POST',
                      request_path: '/example/create' }
    request_event_post = stub_analytics_event_submission.with(body: /web_request/)

    model_event = { environment: 'test',
                    event_type: 'create_entity',
                    entity_table_name: 'candidates' }
    model_event_post = stub_analytics_event_submission.with(body: /create_entity/)

    perform_enqueued_jobs do
      post '/example/create'
    end

    request_uuid = nil # we'll compare this across requests

    expect(request_event_post.with do |req|
      body = JSON.parse(req.body)
      payload = body['rows'].first['json']
      expect(payload.except('occurred_at', 'request_uuid')).to match(a_hash_including(request_event.stringify_keys))

      request_uuid = payload['request_uuid']
    end).to have_been_made

    expect(model_event_post.with do |req|
      body = JSON.parse(req.body)
      payload = body['rows'].first['json']
      expect(payload.except('occurred_at', 'request_uuid')).to match(a_hash_including(model_event.stringify_keys))

      expect(payload['request_uuid']).to eq(request_uuid)
    end).to have_been_made
  end

  context 'when a queue is specified' do
    it 'uses the specified queue' do
      with_analytics_config(queue: :my_custom_queue) do
        expect do
          get '/example'
        end.to have_enqueued_job.on_queue(:my_custom_queue)
      end
    end
  end

  context 'when no queue is specified' do
    it 'uses the default queue' do
      expect do
        get '/example'
      end.to have_enqueued_job.on_queue(:default)
    end
  end

  context 'when a non-UTF-8-encoded User Agent is supplied' do
    it 'coerces it to UTF-8' do
      stub_analytics_event_submission.with(body: /web_request/)

      string = "\xbf\xef"

      expect do
        perform_enqueued_jobs do
          get '/example', headers: { 'User-Agent' => string }
        end
      end.not_to raise_error
    end
  end
end
