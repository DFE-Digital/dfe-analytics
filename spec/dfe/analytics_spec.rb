# frozen_string_literal: true

RSpec.describe DfE::Analytics do
  it 'has a version number' do
    expect(DfE::Analytics::VERSION).not_to be nil
  end

  it 'has documentation entries for all the config options' do
    config_options = DfE::Analytics.config.members

    config_options.each do |option|
      expect(I18n.t("dfe.analytics.config.#{option}.description")).not_to match(/translation missing/)
      expect(I18n.t("dfe.analytics.config.#{option}.default")).not_to match(/translation missing/)
    end
  end

  describe 'when no database connection is available' do
    it 'recovers and logs' do
      allow(ActiveRecord::Base).to receive(:connection).and_raise(ActiveRecord::ConnectionNotEstablished)
      allow(Rails.logger).to receive(:info).with(/No database connection/)
      expect { DfE::Analytics.initialize! }.not_to raise_error
    end
  end

  describe 'when migrations are pending' do
    it 'recovers and logs' do
      allow(DfE::Analytics::Fields).to receive(:check!).and_raise(ActiveRecord::PendingMigrationError)

      allow(Rails.logger).to receive(:info).with(/Database requires migration/)
      expect { DfE::Analytics.initialize! }.not_to raise_error
    end
  end

  describe 'field checks on initialization' do
    # field validity is computed from allowlist, blocklist and database. See
    # Analytics::Fields for more details

    with_model :Candidate do
      table
    end

    context 'when the field lists are valid' do
      before do
        allow(DfE::Analytics).to receive(:allowlist).and_return(
          Candidate.table_name.to_sym => ['id']
        )
      end

      it 'raises no error' do
        expect { DfE::Analytics.initialize! }.not_to raise_error
      end
    end

    context 'when a field list is invalid' do
      before do
        allow(DfE::Analytics).to receive(:allowlist).and_return({ invalid: [:fields] })
      end

      it 'raises an error' do
        expect { DfE::Analytics.initialize! }.to raise_error(DfE::Analytics::ConfigurationError)
      end
    end
  end

  describe 'auto-inclusion of model callbacks' do
    context 'when a model has not included DfE::Analytics::Entities' do
      with_model :Candidate do
        table
      end

      before do
        allow(DfE::Analytics).to receive(:allowlist).and_return(
          Candidate.table_name.to_sym => ['id']
        )
      end

      it 'includes it' do
        expect(Candidate.include?(DfE::Analytics::Entities)).to be false

        DfE::Analytics.initialize!

        expect(Candidate.include?(DfE::Analytics::Entities)).to be true
      end
    end

    context 'when models have already included DfE::Analytics::Entities' do
      with_model :Candidate do
        table

        model do
          include DfE::Analytics::Entities
        end
      end

      with_model :School do
        table

        model do
          include DfE::Analytics::Entities
        end
      end

      before do
        allow(DfE::Analytics).to receive(:allowlist).and_return(
          Candidate.table_name.to_sym => ['id'],
          School.table_name.to_sym => ['id']
        )
      end

      it 'logs deprecation warnings' do
        allow(Rails.logger).to receive(:info).and_call_original

        DfE::Analytics.initialize!

        expect(Rails.logger).to have_received(:info).twice.with(/DEPRECATION WARNING/)
      end
    end
  end

  it 'raises a configuration error on missing config values' do
    with_analytics_config(bigquery_project_id: nil) do
      DfE::Analytics::Testing.webmock! do
        expect { DfE::Analytics.events_client }.to raise_error(DfE::Analytics::ConfigurationError)
      end
    end
  end

  describe '#entities_for_analytics' do
    with_model :Candidate do
      table

      model do
        include DfE::Analytics::Entities
      end
    end

    before do
      allow(DfE::Analytics).to receive(:allowlist).and_return({
        Candidate.table_name.to_sym => %i[id]
      })
    end

    it 'returns the entities in the allowlist' do
      expect(DfE::Analytics.entities_for_analytics).to eq [Candidate.table_name.to_sym]
    end
  end

  describe '#user_identifier' do
    let(:user_class) { Struct.new(:id) }
    let(:id) { rand(1000) }
    let(:user) { user_class.new(id) }

    it 'calls the user_identifier configation' do
      expect(described_class.user_identifier(user)).to eq id
    end

    context 'with a customised user_identifier proc' do
      let(:user_class) { Struct.new(:identifier) }

      before do
        allow(described_class.config).to receive(:user_identifier)
                                           .and_return(->(user) { user.identifier })
      end

      it 'delegates to the provided proc' do
        expect(described_class.user_identifier(user)).to eq id
      end
    end
  end
end
