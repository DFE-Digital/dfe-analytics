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
                                               'request_path' => '/path',
                                               'request_query' => [{ 'key' => 'a', 'value' => ['b'] }],
                                               'request_referer' => nil
                                             })
  end

  describe 'anonymised_user_agent_and_ip' do
    subject do
      request = fake_request(
        headers: headers,
        user_agent: user_agent
      )

      event = described_class.new
      event.with_request_details(request).as_json['anonymised_user_agent_and_ip']
    end

    context 'user agent and IP are both present' do
      let(:user_agent) { 'SomeClient' }
      let(:headers) { { 'X-REAL-IP' => '1.2.3.4' } }

      it { is_expected.to eq '90d5c396fe8da875d25688dfec3f2881c52e81507614ba1958262c8443db29c5' }
    end

    context 'user agent is present but IP is not' do
      let(:user_agent) { 'SomeClient' }
      let(:headers) { { 'X-REAL-IP' => nil } }

      it { is_expected.to be_nil }
    end

    context 'IP is present but user agent is not' do
      let(:user_agent) { nil }
      let(:headers) { { 'X-REAL-IP' => '1.2.3.4' } }

      it { is_expected.to eq '6694f83c9f476da31f5df6bcc520034e7e57d421d247b9d34f49edbfc84a764c' }
    end

    context 'neither IP not user agent is present' do
      let(:user_agent) { nil }
      let(:headers) { { 'X-REAL-IP' => nil } }

      it { is_expected.to be_nil }
    end
  end

  describe 'data pairs' do
    let(:event) { described_class.new }
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

    def find_data_pair(output, key)
      output['data'].find { |pair| pair['key'] == key }
    end

    it 'converts data types to their string representations' do
      boolean_output = event.with_data(data: { boolean_key: true }, hidden_data: {}).as_json
      expect(find_data_pair(boolean_output, 'boolean_key')['value']).to eq(['true'])
    end

    it 'converts hashes to strings' do
      hash_output = event.with_data(data: { hash_key: { equality_and_diversity: { ethnic_background: 'Irish' } } }, hidden_data: {}).as_json
      expect(find_data_pair(hash_output, 'hash_key')['value']).to eq(['{"equality_and_diversity":{"ethnic_background":"Irish"}}'])
    end

    it 'strips out nil values and logs a warning' do
      expect(Rails.logger).to receive(:warn).with(/DfE::Analytics an array field contains nulls/)
      nil_values_output = event.with_data(data: { key_with_nil: ['A', nil, nil] }, hidden_data: {}).as_json
      expect(find_data_pair(nil_values_output, 'key_with_nil')['value']).to eq(['A'])
    end

    it 'handles objects that have JSON-friendly structures' do
      output = event.with_data(data: { as_json_object: has_as_json_class.new('green', true) }, hidden_data: {}).as_json

      expect(output['data'].first['value']).to eq ['{"colour":"green","is_cat":true}']
      puts has_as_json_class.new('green', true).as_json.to_json
    end

    it 'handles arrays of JSON-friendly structures' do
      output = event.with_data(data: { as_json_object: [has_as_json_class.new('green', true)] }, hidden_data: {}).as_json

      expect(output['data']).not_to be_nil
      expect(output['data']).not_to be_empty

      found_key_value_pair = output['data'].find { |pair| pair['key'] == 'as_json_object' }
      expect(found_key_value_pair).not_to be_nil
      expect(found_key_value_pair['value']).to eq(['{"colour":"green","is_cat":true}'])
    end

    it 'behaves correctly when with_data is called with empty data and hidden_data' do
      event.with_data(data: {}, hidden_data: {})
      updated_event_hash = event.as_json
      expect(updated_event_hash['data']).to eq([])
      expect(updated_event_hash['hidden_data']).to eq([])
    end

    it 'remain backwards compatible when with_data is called without the :data and :hidden_data keys' do
      event.with_data(some: 'custom details about event', ethnic_background: 'Red')
      updated_event_hash = event.as_json

      data_some_key = updated_event_hash['data'].find { |d| d['key'] == 'some' }
      expect(data_some_key).not_to be_nil
      expect(data_some_key['value']).to eq(['custom details about event'])

      data_ethnic_background_key = updated_event_hash['data'].find { |d| d['key'] == 'ethnic_background' }
      expect(data_ethnic_background_key).not_to be_nil
      expect(data_ethnic_background_key['value']).to eq(['Red'])

      expect(updated_event_hash['hidden_data']).to be_nil
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

    it 'uses user.id by default without pseudonymisation' do
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

  describe 'custom events with hidden_data' do
    let(:type) { 'some_custom_event' }

    before do
      allow(DfE::Analytics).to receive(:custom_events).and_return [type]
    end

    it 'includes hidden_data in the event payload' do
      event = DfE::Analytics::Event.new
               .with_type(type)
               .with_request_details(fake_request)
               .with_namespace('some_namespace')
               .with_data(
                 data: { some: 'custom details about event' },
                 hidden_data: { some_hidden: 'some data to be hidden' }
               )
      output = event.as_json

      visible_data = output['data'].find { |d| d['key'] == 'some' }
      hidden_data = output['hidden_data'].find { |d| d['key'] == 'some_hidden' }

      expect(visible_data).not_to be_nil
      expect(visible_data['value']).to eq(['custom details about event'])

      expect(hidden_data).not_to be_nil
      expect(hidden_data['value']).to eq(['some data to be hidden'])
    end
  end

  def fake_request(overrides = {})
    attrs = {
      uuid: '123',
      method: 'GET',
      original_fullpath: '/path?a=b',
      query_string: 'a=b',
      referer: nil,
      user_agent: 'SomeClient',
      headers: { 'X-REAL-IP' => '1.2.3.4' }
    }.merge(overrides)

    instance_double(ActionDispatch::Request, attrs)
  end
end
