# frozen_string_literal: true

RSpec.describe DfE::Analytics do
  it 'has a version number' do
    expect(DfE::Analytics::VERSION).not_to be nil
  end

  it 'supports the anonymise method for backwards compatibility' do
    expect(DfE::Analytics.anonymise('foo_bar')).to eq('4928cae8b37b3d1113f5e01e60c967df6c2b9e826dc7d91488d23a62fec715ba')
  end

  it 'has documentation entries for all the config options' do
    config_options = DfE::Analytics.config.members

    config_options.each do |option|
      expect(I18n.t("dfe.analytics.config.#{option}.description")).not_to match(/translation missing/)
      expect(I18n.t("dfe.analytics.config.#{option}.default")).not_to match(/translation missing/)
    end
  end

  describe 'when no database connection is available on rails 7.2 or higher' do
    before do
      allow(Rails).to receive(:version).and_return('7.2')
      allow(ActiveRecord::Base).to receive(:with_connection).and_raise(ActiveRecord::ConnectionNotEstablished)
    end

    it 'recovers and logs' do
      expect(Rails.logger).to receive(:error).with(/No database connection/)
      expect { DfE::Analytics.initialize! }.not_to raise_error
    end
  end

  describe 'when no database connection is available on rails 7.1 or lower' do
    before do
      allow(Rails).to receive(:version).and_return('7.1')
      allow(ActiveRecord::Base).to receive(:connection).and_raise(ActiveRecord::ConnectionNotEstablished)
    end

    it 'recovers and logs' do
      expect(Rails.logger).to receive(:error).with(/No database connection/)
      expect { DfE::Analytics.initialize! }.not_to raise_error
    end
  end

  describe 'when migrations are pending' do
    it 'recovers and logs' do
      allow(DfE::Analytics::Fields).to receive(:check!).and_raise(ActiveRecord::PendingMigrationError)

      expect(Rails.logger).to receive(:error).with(/Database requires migration/)
      expect { DfE::Analytics.initialize! }.not_to raise_error
    end
  end

  describe 'when ActiveRecord is not loaded' do
    it 'recovers and logs' do
      hide_const('ActiveRecord')

      expect(Rails.logger).to receive(:info).with(/ActiveRecord not loaded; DfE Analytics will only track non-database requests./)
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
        allow(Rails.logger).to receive(:warn).and_call_original

        DfE::Analytics.initialize!

        expect(Rails.logger).to have_received(:warn).twice.with(/DEPRECATION WARNING/)
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
                                           .and_return(lambda(&:identifier))
      end

      it 'delegates to the provided proc' do
        expect(described_class.user_identifier(user)).to eq id
      end
    end
  end

  describe '.extract_model_attributes' do
    with_model :Candidate do
      table do |t|
        t.string :email_address
        t.string :hidden_data
        t.integer :age
      end
    end

    before do
      allow(DfE::Analytics).to receive(:allowlist).and_return({
        Candidate.table_name.to_sym => %w[email_address hidden_data age]
      })
      allow(DfE::Analytics).to receive(:hidden_pii).and_return({
        Candidate.table_name.to_sym => %w[hidden_data age]
      })
    end

    let(:candidate) { Candidate.create(email_address: 'test@example.com', hidden_data: 'secret', age: 50) }

    it 'correctly separates and obfuscates attributes' do
      result = described_class.extract_model_attributes(candidate)

      expect(result[:data].keys).to include('email_address')
      expect(result[:hidden_data]['hidden_data']).to eq('secret')
      expect(result[:hidden_data]['age']).to eq(50)
    end

    it 'correctly separates allowed and hidden attributes' do
      result = described_class.extract_model_attributes(candidate)

      expect(result[:data].keys).to include('email_address')
      expect(result[:data]).not_to have_key('hidden_data')
      expect(result[:data]).not_to have_key('age')

      expect(result[:hidden_data]['hidden_data']).to eq('secret')
      expect(result[:hidden_data]['age']).to eq(50)
    end

    it 'does not error if no hidden data is sent' do
      candidate = Candidate.create(email_address: 'test@example.com')
      allow(DfE::Analytics).to receive(:allowlist).and_return(Candidate.table_name.to_sym => %w[email_address])

      result = described_class.extract_model_attributes(candidate)
      expect(result[:data].keys).to include('email_address')
      expect(result[:hidden_data]).to be_nil.or be_empty
      expect { DfE::Analytics.extract_model_attributes(candidate) }.not_to raise_error
    end
  end

  describe '.parse_maintenance_window' do
    context 'with a valid maintenance window' do
      before do
        allow(described_class.config).to receive(:bigquery_maintenance_window)
          .and_return('01-01-2020 00:00..01-01-2020 23:59')
      end

      it 'returns the correct start and end times' do
        start_time, end_time = described_class.parse_maintenance_window
        expect(start_time).to eq(DateTime.new(2020, 1, 1, 0, 0))
        expect(end_time).to eq(DateTime.new(2020, 1, 1, 23, 59))
      end
    end

    context 'when start time is after end time' do
      before do
        allow(described_class.config).to receive(:bigquery_maintenance_window)
          .and_return('01-01-2020 23:59..01-01-2020 00:00')
      end

      it 'logs an error and returns [nil, nil]' do
        expect(Rails.logger).to receive(:warn).with(/Start time is after end time/)
        expect(described_class.parse_maintenance_window).to eq([nil, nil])
      end
    end

    context 'with an invalid format' do
      before do
        allow(described_class.config).to receive(:bigquery_maintenance_window)
          .and_return('invalid_format')
      end

      it 'logs an error and returns [nil, nil]' do
        expect(Rails.logger).to receive(:error).with(/Unexpected error/)
        expect(described_class.parse_maintenance_window).to eq([nil, nil])
      end
    end
  end

  describe '.within_maintenance_window?' do
    context 'when the current time is within the maintenance window' do
      before do
        allow(described_class).to receive(:parse_maintenance_window)
          .and_return([DateTime.now - 1.hour, DateTime.now + 1.hour])
      end

      it 'returns true' do
        expect(described_class.within_maintenance_window?).to be true
      end
    end

    context 'when the current time is outside the maintenance window' do
      before do
        allow(described_class).to receive(:parse_maintenance_window)
          .and_return([DateTime.now - 2.days, DateTime.now - 1.day])
      end

      it 'returns false' do
        expect(described_class.within_maintenance_window?).to be false
      end
    end
  end

  describe 'excluding models via configuration' do
    with_model :Candidate do
      table do |t|
        t.string :email_address
        t.string :first_name
        t.string :last_name
        t.string :dob
      end
    end

    with_model :Teacher do
      table do |t|
        t.string :email_address
        t.string :first_name
        t.string :last_name
        t.string :dob
      end
    end

    before do
      DfE::Analytics.config.excluded_models_proc = proc { |x| x.to_s =~ /Teacher/ }
    end

    it 'does not use disabled model' do
      expect(DfE::Analytics.all_entities_in_application.length).to eq(1)
      expect(DfE::Analytics.all_entities_in_application.first.to_s).to match(/with_model_candidates/)
    end
  end

  describe 'when ActiveRecord is not available' do
    before do
      hide_const('ActiveRecord')
    end

    it 'initializes without errors' do
      expect { DfE::Analytics.initialize! }.not_to raise_error
    end
  end
end
