
desc "Synchronize all resources between Ringio and Highrise CRM"
task :synchronize_all => :environment do
  ApiOperations::Common.log(:info,nil,"Started complete synchronization event")
  Rails.logger.flush

  begin
    ApiOperations::Common.complete_synchronization
  rescue Exception => e
    ApiOperations::Common.log(:error,e,"\nProblem with the initializing of the synchronization")
  end
  
  ApiOperations::Common.log(:info,nil,"Finished complete synchronization event\n")
  Rails.logger.flush
end