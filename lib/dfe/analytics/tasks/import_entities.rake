namespace :dfe do
  namespace :analytics do
    desc 'Send Analytics events for the (allowlisted) state of all records in the database'
    task :import_all_entities, %i[sleep_time batch_size] => :environment do |_, args|
      models_for_analytics.each do |model_name|
        DfE::Analytics::LoadEntities.new(model_name: model_name, **args).run
      end
    end

    desc 'Send Analytics events for the state of all records in a specified model'
    task :import_entity, %i[model_name sleep_time batch_size start_at_id] => :environment do |_, args|
      abort('You need to specify a model name as an argument to the Rake task, eg dfe:analytics:import_entity[Model]') unless args[:model_name]

      DfE::Analytics::LoadEntities.new(args).run
    end
  end
end
