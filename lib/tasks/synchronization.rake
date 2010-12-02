
desc "Synchronize resources between Ringio and Highrise CRM"
task :synchronize => :environment do
  ApiOperations.synchronize
end