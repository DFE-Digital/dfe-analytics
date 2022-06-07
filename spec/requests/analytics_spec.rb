RSpec.describe 'Analytics flow', type: :request do
  before do
    model = Class.new(Candidate) do
      include DfE::Analytics::Entities
    end

    stub_const('Candidate', model)

    controller = Class.new(ApplicationController) do
      include DfE::Analytics::Requests

      def index
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
      get '/example/path' => 'test#index'
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
                      request_method: 'GET',
                      request_path: '/example/path' }
    request_event_post = stub_analytics_event_submission.with(body: /web_request/)

    model_event = { environment: 'test',
                    event_type: 'create_entity',
                    entity_table_name: 'candidates' }
    model_event_post = stub_analytics_event_submission.with(body: /create_entity/)

    perform_enqueued_jobs do
      get '/example/path'
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

  context "when a queue is specified" do
    it 'uses the specified queue' do
      with_analytics_config(queue: :my_custom_queue) do
        expect {
          get '/example/path'
        }.to have_enqueued_job.twice.on_queue(:my_custom_queue)
      end
    end
  end

  context "when no queue is specified" do
    it 'uses the default queue' do
      expect {
        get '/example/path'
      }.to have_enqueued_job.twice.on_queue(:default)
    end
  end
end
