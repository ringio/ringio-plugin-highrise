module ApiOperations

  module Common


    INITIAL_DATETIME = (DateTime.parse('1900-01-01 00:00:01')).to_time
    INITIAL_MS_DATETIME = 1

    
    def self.mails_for_select(rg_account_id)
      mails = []
      (RingioAPI::Feed.find(:one, :from => RingioAPI::Feed.prefix + "feeds/accounts/" + rg_account_id.to_s + "/users" )).updated.each do |rg_user_id|
        mails << [(RingioAPI::User.find(rg_user_id)).email,rg_user_id]
      end
      mails
    end


    def self.set_hr_base(user_map)
      Highrise::Base.site = 'https://' + user_map.account.hr_subdomain + '.highrisehq.com' 
      Highrise::Base.user = user_map.hr_user_token
    end


    def self.empty_hr_base
      Highrise::Base.site = ''
      Highrise::Base.user = ''
    end
    

    def self.hr_current_timestamp account
      timestamp = nil

      ApiOperations::Common.set_hr_base account.user_maps.first

      # TODO: find how to get this faster: from the HTTP header Date from the last Highrise response (ActiveResource does not give access to it)
      # create a fake contact, set timestamp to the created_at in the response and then destroy that fake contact
      timestamp_person = Highrise::Person.new(:first_name => 'Ringio Check')
      timestamp_person.save!
      timestamp = timestamp_person.created_at
      timestamp_person.destroy

      ApiOperations::Common.empty_hr_base          

      timestamp
    end
    
  
    # run a complete synchronization event between Ringio and Highrise
    def self.complete_synchronization
      # TODO: handle optional fields for all resources in Ringio and in Highrise
      totalAccounts = Account.all.count.to_s
      currentAccount = 0
      ApiOperations::Common.log(:info,nil,"Beginning Sync: " + Account.all.count.to_s + " accounts")
      Account.all.each do |account|
        begin
          ApiOperations::Common.log(:info,nil,"Synchronizing account id = " + account.rg_account_id.to_s + " (" + (currentAccount += 1).to_s + " of " + totalAccounts.to_s + ")")
          self.synchronize_account account
        rescue Exception => e
          ApiOperations::Common.log(:error,e,"Problem with the initialization of the synchronization of the account with id = " + account.id.to_s)
        end
      end
      ApiOperations::Common.log(:info,nil,"\nCompleted Sync")
      return
    end

    # run a single account synchronization event between Ringio and Highrise
    def self.single_account_synchronization(account)
      # TODO: handle optional fields for all resources in Ringio and in Highrise
      (account.class == Account) ? self.synchronize_account(account) : ApiOperations::Common.log(:error,nil,"\nProblem during a single account synchronization for " + account.inspect)  
      return
    end

    
    def self.log(level,exception,message)
      mark = '[' + Time.now.to_s + '] [' + level.to_s.upcase + '] '
      no_exception_message = mark + message + "\n"
      case level
        when :debug then Rails.logger.debug no_exception_message
        when :info then Rails.logger.info no_exception_message
        when :warn then Rails.logger.warn no_exception_message
        when :error
          if exception
            Rails.logger.error no_exception_message + "  " + exception.inspect + "\n" + exception.backtrace.inject(''){|error_message, error_line| error_message << "  " + error_line + "\n"} + "\n"
          else
            Rails.logger.error no_exception_message            
          end
        else raise 'Unhandled log level'
      end
    end

 
    def self.empty_rg_contacts(user_map)
      user_map.all_rg_contacts_feed.updated.each{|rg_c_id| (RingioAPI::Contact.find(rg_c_id)).destroy}
    end
  
  
    def self.empty_hr_parties(user_map)
      ApiOperations::Common.set_hr_base user_map
      feed = user_map.hr_parties_feed true
      feed[0].each{|hr_person| hr_person.destroy}
      feed[1].each{|hr_company| hr_company.destroy}
      ApiOperations::Common.empty_hr_base    
    end

    #Transforms any of the possible times in this application into iso8601
    def self.fixTime(time)
      if time.class == Fixnum || time.class == Bignum
        if(time > 1000000000)
          time = Time.at(time).iso8601
        elsif
          time = Time.mktime(time).iso8601
        end
      elsif time.class == ActiveSupport::TimeWithZone
        time = time.iso8601
      end
      time
    end
    
    private

      def self.synchronize_account(account)
        begin
          account.rg_resource_account
          account_found = true
        rescue ActiveResource::ResourceNotFound
          account_found = false
          ApiOperations::Common.log(:warn,nil,"\nCould not find account with id = " + account.id.to_s)
        end
        if account_found && account.hr_subdomain.present? && account.user_maps.present? && self.are_tokens_correct(account)
          new_user_maps = account.user_maps.inject([]) do |total,um|
            if um.not_synchronized_yet
              total << um
              um.not_synchronized_yet = false
              um.save!
            end
            total
          end

          # we synchronize in reverse order of resource dependency: first contacts, then notes and then rings
          ApiOperations::Contacts.synchronize_account(account,new_user_maps)
          account.reload
          new_user_maps.each{|um| um.reload }
          ApiOperations::Notes.synchronize_account(account,new_user_maps)
          account.reload
          new_user_maps.each{|um| um.reload}
          
          ApiOperations::Rings.synchronize_account(account,new_user_maps)
          account.reload
          new_user_maps.each{|um| um.reload}
          
          if account.not_synchronized_yet
            account.not_synchronized_yet = false
            account.save!
          else
            account.account_last_synchronized_at = DateTime.now
            account.save!
          end
        end
      end
    
    
      def self.are_tokens_correct(account)
        result = nil
        
        account.user_maps.each do |um|
          ApiOperations::Common.set_hr_base um
    
          begin
            user_hr = Highrise::User.me
            result = true
          rescue ActiveResource::UnauthorizedAccess
            result = false
          rescue ActiveResource::ResourceNotFound
            result = false
          end

          ApiOperations::Common.empty_hr_base

          unless result
            ApiOperations::Common.log(:warn,nil,"\nProblem accessing the user with Highrise id = " + um.hr_user_id.to_s)
            break
          end
        end
        
        result
      end


  end
  
end