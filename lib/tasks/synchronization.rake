
desc "Synchronize all resources between Ringio and Highrise CRM"
task :synchronize_all => :environment do
  previous_flushing = Rails.logger.auto_flushing
  Rails.logger.auto_flushing = true 
  
  ApiOperations::Common.log(:info,nil,"Started complete synchronization event")

  begin
    ApiOperations::Common.complete_synchronization
  rescue Exception => e
    ApiOperations::Common.log(:error,e,"\nProblem with the initializing of the synchronization")
  end
  
  ApiOperations::Common.log(:info,nil,"Finished complete synchronization event\n")
  
  Rails.logger.auto_flushing = previous_flushing
end

desc "Synchronize all resources between Ringio and Highrise CRM - version for debugging"
task :synchronize_all_debugging => :environment do
  # get the previous logger configuration
  previous_level = Rails.logger.level

  # set the logger properly for debugging
  Rails.logger.level = 0

  # run the synchronization
  Rake::Task['synchronize_all'].invoke

  # restore the previous logger configuration
  Rails.logger.level = previous_level
end

desc "Synchronize ONE account between Ringio and Highrise CRM - version for debugging, pass Ringio account id as argument"
task :synchronize_one_debugging, [:rg_account_id] => [:environment] do |t,args|
  # get the previous logger configuration
  previous_level = Rails.logger.level
  previous_flushing = Rails.logger.auto_flushing

  # set the logger properly for debugging
  Rails.logger.level = 0
  Rails.logger.auto_flushing = true 

  # run the synchronization
  ApiOperations::Common.log(:info,nil,"Started single synchronization event for the account with Ringio id = " + args.rg_account_id)
  begin
    ApiOperations::Common.single_account_synchronization(Account.find_by_rg_account_id(args.rg_account_id))
  rescue Exception => e
    ApiOperations::Common.log(:error,e,"\nProblem with the initializing of the single synchronization for the account with Ringio id = " + args.rg_account_id)
  end
  ApiOperations::Common.log(:info,nil,"Finished single synchronization event for the account with Ringio id = " + args.rg_account_id + "\n")

  # restore the previous logger configuration
  Rails.logger.level = previous_level
  Rails.logger.auto_flushing = previous_flushing
end

desc "Synchronize all, but with good programming practice"
task :sync_all_smart => :environment do
  totalAccounts = Account.all.count.to_s
  currentAccount = 0
  ApiOperations::Common.log(:info,nil,"Beginning Sync: " + totalAccounts + " accounts")
  Account.all.each do |act|
    ApiOperations::Common.log(:info,nil,"Synchronizing account id = " + act.rg_account_id.to_s + " (" + (currentAccount += 1).to_s + " of " + totalAccounts + ")")
    system("#{RAILS_ROOT}/script/sync_one.sh " + act.rg_account_id.to_s)
  end
  ApiOperations::Common.log(:info,nil,"\nCompleted Sync")
end

