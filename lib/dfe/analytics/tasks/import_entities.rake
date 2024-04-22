namespace :dfe do
  namespace :analytics do
    desc 'Send Analytics events for the (allowlisted) state of all records in the database'
    task :import_all_entities, %i[batch_size] => :environment do |_, args|
      return unless DfE::Analytics.enabled?

      puts 'DfE Analytics is not enabled - Ignoring import_all_entities'

      entity_tag = Time.now.strftime('%Y%m%d%H%M%S')
      DfE::Analytics.entities_for_analytics.each do |entity_name|
        DfE::Analytics::LoadEntities.new(entity_name: entity_name, **args).run(entity_tag: entity_tag)
        DfE::Analytics::Services::EntityTableChecks.call(entity_name: entity_name, entity_type: 'import_entity_table_check', entity_tag: entity_tag)
      end
    end

    desc 'Send Analytics events for the state of all records in a specified model'
    task :import_entity, %i[entity_name batch_size] => :environment do |_, args|
      return unless DfE::Analytics.enabled?

      puts 'DfE Analytics is not enabled - Ignoring import_entity'

      abort('You need to specify a model name as an argument to the Rake task, eg dfe:analytics:import_entity[Model]') unless args[:entity_name]
      entity_tag = Time.now.strftime('%Y%m%d%H%M%S')
      DfE::Analytics::LoadEntities.new(**args).run(entity_tag: entity_tag)
      DfE::Analytics::Services::EntityTableChecks.call(
        entity_name: args[:entity_name],
        entity_type: 'import_entity_table_check',
        entity_tag: entity_tag
      )
    end
  end
end
