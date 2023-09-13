RSpec.describe 'Analytics flow', type: :request do
  with_model :Candidate do
    table do |t|
      t.string :email_address
      t.string :first_name
      t.string :last_name
    end
  end

  before do
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
      Candidate.table_name.to_sym => %w[id email_address]
    })

    # autogenerate a compliant blocklist
    allow(DfE::Analytics).to receive(:blocklist).and_return(DfE::Analytics::Fields.generate_blocklist)

    DfE::Analytics.initialize!

    Rails.application.routes.draw do
      post '/example/create' => 'test#create'
      get '/example/' => 'test#index'
    end
  end

  around do |ex|
    DfE::Analytics::Testing.webmock! do
      ex.run
    end
  end

  after do
    Rails.application.routes_reloader.reload!
  end

  describe 'end-to-end API calls' do
    let!(:initialise_event_post) { stub_analytics_event_submission.with(body: /initialise_analytics/) }
    let!(:request_event_post) { stub_analytics_event_submission.with(body: /request_path/) }
    let!(:model_event_post) { stub_analytics_event_submission.with(body: /create_entity/) }
    # let!(:entity_table_check_event_post) { stub_analytics_event_submission.with(body: /entity_table_check/) }

    let(:initialise_event) do
      {
        environment: 'test',
        event_type: 'initialise_analytics'
      }
    end

    let(:request_event) do
      {
        environment: 'test',
        event_type: 'web_request',
        request_method: 'POST',
        request_path: '/example/create'
      }
    end

    let(:model_event) do
      {
        environment: 'test',
        event_type: 'create_entity',
        entity_table_name: Candidate.table_name
      }
    end

    # let(:entity_table_check_event) do
    #   {
    #     environment: 'test',
    #     event_type: 'entity_table_check',
    #     entity_table_name: Candidate.table_name
    #   }
    # end

    before do
      DfE::Analytics::InitialisationEvents.initialisation_events_sent = initialisation_events_sent

      perform_enqueued_jobs do
        post '/example/create'
      end
    end

    context 'when initialise_analytics event NOT already sent' do
      let(:initialisation_events_sent) { false }

      it 'calls the expected BigQuery APIs' do
        request_uuid = nil # we'll compare this across requests

        expect(initialise_event_post.with do |req|
          body = JSON.parse(req.body)
          payload = body['rows'].first['json']
          expect(payload.except('occurred_at')).to match(a_hash_including(initialise_event.stringify_keys))
        end).to have_been_made

        # expect(entity_table_check_event_post.with do |req|
        #   body = JSON.parse(req.body)
        #   payload = body['rows'].first['json']
        #   expect(payload.except('occurred_at')).to match(a_hash_including(entity_table_check_event.stringify_keys))
        # end).to have_been_made

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
    end

    context 'when initialise_analytics event already sent' do
      let(:initialisation_events_sent) { true }

      it 'calls the expected BigQuery APIs' do
        request_uuid = nil # we'll compare this across requests

        expect(initialise_event_post).to_not have_been_made

        # expect(entity_table_check_event_post).to_not have_been_made

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
    end
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
