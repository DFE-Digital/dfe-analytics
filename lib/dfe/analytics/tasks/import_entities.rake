namespace :dfe do
  namespace :analytics do
    desc 'Send Analytics events for the (allowlisted) state of all records in the database'
    task :import_all_entities, %i[batch_size] => :environment do |_, args|
      entities_for_analytics.each do |entity_name|
        DfE::Analytics::LoadEntities.new(entity_name: entity_name, **args).run
      end
    end

    desc 'Send Analytics events for the state of all records in a specified model'
    task :import_entity, %i[entity_name batch_size] => :environment do |_, args|
      abort('You need to specify a model name as an argument to the Rake task, eg dfe:analytics:import_entity[Model]') unless args[:entity_name]

      DfE::Analytics::LoadEntities.new(args).run
    end
  end
end
