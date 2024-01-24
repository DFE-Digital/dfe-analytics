namespace :dfe do
  namespace :analytics do
    desc 'Send Analytics events for the (allowlisted) state of all records in the database'
    task :import_all_entities, %i[batch_size] => :environment do |_, args|
      import_entity_id = Time.now.strftime('%Y%m%d%H%M%S')
      DfE::Analytics.entities_for_analytics.each do |entity_name|
        DfE::Analytics::LoadEntities.new(entity_name: entity_name, **args).run(import_entity_id)
        DfE::Analytics::EntityProcessor.process_entity_for_import(entity_name, import_entity_id)
      end
    end

    desc 'Send Analytics events for the state of all records in a specified model'
    task :import_entity, %i[entity_name batch_size] => :environment do |_, args|
      abort('You need to specify a model name as an argument to the Rake task, eg dfe:analytics:import_entity[Model]') unless args[:entity_name]

      import_entity_id = Time.now.strftime('%Y%m%d%H%M%S')
      DfE::Analytics::LoadEntities.new(**args).run(import_entity_id)
    end
  end
end
