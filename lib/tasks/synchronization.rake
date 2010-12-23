
desc "Synchronize all resources between Ringio and Highrise CRM"
task :synchronize_all => :environment do
  ApiOperations::Common.log(:info,nil,"Started complete synchronization event")
  Rails.logger.flush

  ApiOperations::Common.complete_synchronization
  
  ApiOperations::Common.log(:info,nil,"Finished complete synchronization event\n")
  Rails.logger.flush
end