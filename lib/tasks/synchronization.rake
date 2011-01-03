
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

desc "Synchronize all resources between Ringio and Highrise CRM - version for debugging"
task :synchronize_all_debugging => :environment do
  # get the previous logger configuration
  previous_level = Rails.logger.level
  previous_flushing = Rails.logger.auto_flushing

  # set the logger properly for debugging
  Rails.logger.level = 0
  Rails.logger.auto_flushing = true 

  # run the synchronization
  Rake::Task['synchronize_all'].invoke

  # restore the previous logger configuration
  Rails.logger.level = previous_level
  Rails.logger.auto_flushing = previous_flushing
end
