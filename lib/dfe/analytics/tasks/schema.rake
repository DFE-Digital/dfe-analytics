namespace :dfe do
  namespace :analytics do
    desc 'Print out the dfe-analytics JSON schema'
    task :schema do
      puts DfE::Analytics::EventSchema.as_json
    end

    desc 'Print out the dfe-analytics BigQuery schema'
    task :big_query_schema do
      puts DfE::Analytics::EventSchema.as_bigquery_schema
    end
  end
end
