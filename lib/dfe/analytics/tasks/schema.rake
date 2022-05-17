namespace :dfe do
  namespace :analytics do
    desc 'Print out the dfe-analytics JSON schema'
    task :schema do
      path = "#{Gem.loaded_specs['dfe-analytics'].gem_dir}/config/event-schema.json"
      puts File.read(path)
    end
  end
end
