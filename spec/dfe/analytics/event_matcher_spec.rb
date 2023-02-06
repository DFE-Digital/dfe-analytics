RSpec.describe DfE::Analytics::EventMatcher do
  subject { described_class.new(event, logging[:event_filters]) }

  context 'when event is a database update' do
    let(:event) do
      {
        'entity_table_name' => 'application_choice_details',
        'event_type' => 'update_entity',
        'data' => [
          { 'key' => 'course_option_id', 'value' => ['12345'] },
          { 'key' => 'application_form_id', 'value' => ['42'] }
        ]
      }
    end

    describe '.matched?' do
      context 'when the table name and event type matches' do
        let(:logging) do
          {
            event_filters: [
              {
                event_type: 'update_entity',
                entity_table_name: 'application_choice_details'
              }
            ]
          }
        end

        it 'returns a successful match' do
          expect(subject).to be_matched
        end

        context 'when a nested hash key field also matches' do
          let(:logging) do
            {
              event_filters: [
                {
                  event_type: 'update_entity',
                  entity_table_name: 'application_choice_details',
                  data: {
                    key: 'course_option_id'
                  }
                }
              ]
            }
          end

          it 'returns a successful match' do
            expect(subject).to be_matched
          end
        end

        context 'when a nested hash key field does not match' do
          let(:logging) do
            {
              event_filters: [
                {
                  event_type: 'update_entity',
                  entity_table_name: 'application_choice_details',
                  data: {
                    key: 'foo_bar'
                  }
                }
              ]
            }
          end

          it 'returns an unsuccessful match' do
            expect(subject).to_not be_matched
          end
        end
      end

      context 'when 1 out of 2 filters match' do
        let(:logging) do
          {
            event_filters: [
              {
                event_type: 'update_entity',
                entity_table_name: 'application_choice_details'
              },
              {
                event_type: 'foo'
              }
            ]
          }
        end

        it 'returns a successful match' do
          expect(subject).to be_matched
        end
      end

      context 'when the filter does not match' do
        let(:logging) do
          {
            event_filters: [
              {
                event_type: 'foo'
              }
            ]
          }
        end

        it 'returns an unsuccessful match' do
          expect(subject).to_not be_matched
        end

        context 'when 2 out of 2 filters do not match' do
          let(:logging) do
            {
              event_filters: [
                {
                  event_type: 'create_entity',
                  entity_table_name: 'application_choice_details'
                },
                {
                  event_type: 'foo'
                }
              ]
            }
          end

          it 'returns an unsuccessful match' do
            expect(subject).to_not be_matched
          end
        end
      end
    end
  end
end
