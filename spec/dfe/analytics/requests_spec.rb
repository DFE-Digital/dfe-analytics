# frozen_string_literal: true

RSpec.describe DfE::Analytics::Requests, type: :request do
  before do
    controller = Class.new(ApplicationController) do
      include DfE::Analytics::Requests
    end
    public_api_controller = Class.new(PublicApiController) do
      include DfE::Analytics::Requests
    end

    stub_const('TestController', controller)
    stub_const('TestPublicApiController', public_api_controller)
  end

  around do |ex|
    Rails.application.routes.draw do
      get '/example/path' => 'test#index'
      get '/api/public/things' => 'test_public_api#index'
    end

    ex.run

  ensure
    Rails.application.routes_reloader.reload!
  end

  let!(:event) do
    { environment: 'test',
      event_type: 'web_request',
      request_user_agent: 'Test agent',
      request_method: 'GET',
      request_path: '/example/path',
      request_query: [{ key: 'page',
                        value: ['1'] },
                      { key: 'per_page',
                        value: ['25'] },
                      { key: 'array_param[]',
                        value: %w[1 2] }],
      request_referer: nil,
      anonymised_user_agent_and_ip: '16859db7ca4ec906925a0a2cb227bf307740a0c919ab9e2f7efeadf37779e770',
      response_content_type: 'text/plain; charset=utf-8',
      response_status: 200,
      namespace: 'ddd',
      user_id: 1 }
  end

  it 'sends request data to BigQuery' do
    request = stub_analytics_event_submission
    DfE::Analytics::Testing.webmock! do
      perform_enqueued_jobs do
        get('/example/path',
            params: { page: '1', per_page: '25', array_param: %w[1 2] },
            headers: { 'HTTP_USER_AGENT' => 'Test agent' })
      end
    end

    expect(request.with do |req|
      body = JSON.parse(req.body)
      payload = body['rows'].first['json']
      expect(payload.except('occurred_at', 'request_uuid')).to match(a_hash_including(event.deep_stringify_keys))
    end).to have_been_made
  end

  describe 'an event without user or namespace' do
    let!(:event) do
      { environment: 'test',
        event_type: 'web_request',
        request_user_agent: nil,
        request_method: 'GET',
        request_path: '/api/public/things',
        request_query: [],
        request_referer: nil,
        anonymised_user_agent_and_ip: '12ca17b49af2289436f303e0166030a21e525d266e209267433801a8fd4071a0',
        response_content_type: 'application/json; charset=utf-8',
        response_status: 200,
        namespace: nil,
        user_id: nil }
    end

    it 'does not require a user' do
      request = stub_analytics_event_submission

      DfE::Analytics::Testing.webmock! do
        perform_enqueued_jobs do
          get('/api/public/things')
        end
      end

      expect(request.with do |req|
        body = JSON.parse(req.body)
        payload = body['rows'].first['json']
        expect(payload.except('occurred_at', 'request_uuid')).to match(a_hash_including(event.deep_stringify_keys))
      end).to have_been_made
    end
  end
end
