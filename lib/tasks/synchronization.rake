
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

desc "Synchronize ONE account between Ringio and Highrise CRM - version for debugging, pass account id as argument"
task :synchronize_one_debugging => :environment do
  # get the previous logger configuration
  previous_level = Rails.logger.level
  previous_flushing = Rails.logger.auto_flushing

  # set the logger properly for debugging
  Rails.logger.level = 0
  Rails.logger.auto_flushing = true 

  # run the synchronization
  ApiOperations::Common.log(:info,nil,"Started single synchronization event for the account with id = " + account_id)
  begin
    ApiOperations::Common.single_account_synchronization(Account.find account_id)
  rescue Exception => e
    ApiOperations::Common.log(:error,e,"\nProblem with the initializing of the single synchronization for the account with id = " + account_id)
  end
  ApiOperations::Common.log(:info,nil,"Finished single synchronization event for the account with id = " + account_id + "\n")

  # restore the previous logger configuration
  Rails.logger.level = previous_level
  Rails.logger.auto_flushing = previous_flushing
end