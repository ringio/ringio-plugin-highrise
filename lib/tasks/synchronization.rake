
desc "Synchronize all resources between Ringio and Highrise CRM"
task :synchronize_all => :environment do
  ApiOperations::Common.complete_synchronization
  Rails.logger.flush
end