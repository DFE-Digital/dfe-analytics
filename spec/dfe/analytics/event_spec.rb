# frozen_string_literal: true

require 'action_dispatch/http/mime_type'
require 'action_dispatch/http/parameters'
require 'action_dispatch/http/content_security_policy'
require 'action_dispatch/http/request'

RSpec.describe DfE::Analytics::Event do
  it 'can append request details' do
    event = described_class.new
    output = event.with_request_details(fake_request).as_json

    expect(output).to match a_hash_including({
                                               'request_uuid' => '123',
                                               'request_user_agent' => 'SomeClient',
                                               'request_method' => 'GET',
                                               'request_path' => '/',
                                               'request_query' => [],
                                               'request_referer' => nil
                                             })
  end

  describe 'anonymised_user_agent_and_ip' do
    subject do
      request = fake_request(
        remote_ip: remote_ip,
        user_agent: user_agent
      )

      event = described_class.new
      event.with_request_details(request).as_json['anonymised_user_agent_and_ip']
    end

    context 'user agent and IP are both present' do
      let(:user_agent) { 'SomeClient' }
      let(:remote_ip) { '1.2.3.4' }

      it { is_expected.to eq '90d5c396fe8da875d25688dfec3f2881c52e81507614ba1958262c8443db29c5' }
    end

    context 'user agent is present but IP is not' do
      let(:user_agent) { 'SomeClient' }
      let(:remote_ip) { nil }

      it { is_expected.to be_nil }
    end

    context 'IP is present but user agent is not' do
      let(:user_agent) { nil }
      let(:remote_ip) { '1.2.3.4' }

      it { is_expected.to eq '6694f83c9f476da31f5df6bcc520034e7e57d421d247b9d34f49edbfc84a764c' }
    end

    context 'neither IP not user agent is present' do
      let(:user_agent) { nil }
      let(:remote_ip) { nil }

      it { is_expected.to be_nil }
    end
  end

  describe 'data pairs' do
    let(:has_as_json_class) do
      Struct.new(:colour, :is_cat) do
        def as_json
          {
            colour: colour,
            is_cat: is_cat
          }
        end
      end
    end

    it 'converts booleans to strings' do
      event = described_class.new
      output = event.with_data(key: true).as_json
      expect(output['data'].first['value']).to eq ['true']
    end

    it 'converts hashes to strings' do
      event = described_class.new
      output = event.with_data(key: { equality_and_diversity: { ethnic_background: 'Irish' } }).as_json
      expect(output['data'].first['value']).to eq ['{"equality_and_diversity":{"ethnic_background":"Irish"}}']
    end

    it 'handles objects that have JSON-friendly structures' do
      event = described_class.new
      output = event.with_data(as_json_object: has_as_json_class.new(:green, true)).as_json
      expect(output['data'].first['value']).to eq ['{"colour":"green","is_cat":true}']
    end

    it 'handles arrays of JSON-friendly structures' do
      event = described_class.new
      output = event.with_data(
        as_json_object: [has_as_json_class.new(:green, true)]
      ).as_json
      expect(output['data'].first['value']).to eq ['{"colour":"green","is_cat":true}']
    end
  end

  describe 'handling invalid UTF-8' do
    it 'coerces it to valid UTF-8' do
      invalid_string = "hello \xbf\xef hello"

      request = fake_request(
        user_agent: invalid_string
      )

      event = described_class.new
      expect(event.with_request_details(request).as_json['request_user_agent']).not_to eq(invalid_string)
      expect(event.with_request_details(request).as_json['request_user_agent']).to eq('hello �� hello')
    end

    it 'handles nil' do
      request = fake_request(
        user_agent: nil
      )

      event = described_class.new
      expect(event.with_request_details(request).as_json['request_user_agent']).to be_nil
    end
  end

  describe 'with_user' do
    let(:regular_user_class) { Struct.new(:id) }

    it 'uses user.id by default' do
      event = described_class.new
      id = rand(1000)
      output = event.with_user(regular_user_class.new(id)).as_json
      expect(output['user_id']).to eq id
    end

    context 'users that use uuid as an identifier' do
      let(:custom_user_class) { Struct.new(:uuid) }

      before do
        allow(DfE::Analytics).to receive(:user_identifier, &:uuid)
      end

      it 'uses the user_identifier proc to extract user id' do
        event = described_class.new
        uuid = SecureRandom.uuid
        output = event.with_user(custom_user_class.new(uuid)).as_json

        expect(output['user_id']).to eq uuid
      end
    end
  end

  describe 'with_type' do
    context 'when called with any of the internal event types' do
      let(:type) { DfE::Analytics::Event::EVENT_TYPES.sample }

      it 'assigns event type' do
        subject.with_type(type)
        expect(subject.as_json['event_type']).to eq type
      end
    end

    context 'when called with a type added to custom events' do
      let(:type) { 'some_custom_event' }

      before do
        allow(DfE::Analytics).to receive(:custom_events).and_return [type]
      end

      it 'assigns event type' do
        subject.with_type(type)
        expect(subject.as_json['event_type']).to eq type
      end
    end

    context 'when called with a type which is neither internal event type nor added to custom event list' do
      let(:type) { 'some_custom_event' }

      it 'raises exception' do
        expect { subject.with_type(type) }.to raise_error
      end
    end
  end

  def fake_request(overrides = {})
    attrs = {
      uuid: '123',
      method: 'GET',
      path: '/',
      query_string: '',
      referer: nil,
      user_agent: 'SomeClient',
      remote_ip: '1.2.3.4'
    }.merge(overrides)

    instance_double(ActionDispatch::Request, attrs)
  end
end
