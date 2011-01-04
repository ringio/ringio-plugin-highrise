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
    

    def self.hr_current_timestamp(user_map)
      timestamp = nil

      if user_map
        ApiOperations::Common.set_hr_base user_map
  
        # TODO: find how to get this faster: from the HTTP header Date from the last Highrise response (ActiveResource does not give access to it)
        # create a fake contact, set timestamp to the created_at in the response and then destroy that fake contact
        timestamp_person = Highrise::Person.new(:first_name => 'Ringio Check')
        timestamp_person.save
        timestamp = timestamp_person.created_at
        timestamp_person.destroy
  
        ApiOperations::Common.empty_hr_base
      end

      timestamp
    end
    
  
    # run a complete synchronization event between Ringio and Highrise
    def self.complete_synchronization
      # TODO: handle optional fields for all resources in Ringio and in Highrise
      Account.all.each do |account|
        if account.hr_subdomain.present?
          new_user_maps = account.user_maps.inject([]) do |total,um|
            if um.not_synchronized_yet
              total << um
              um.not_synchronized_yet = false
              um.save
            end
            total
          end
          self.synchronize_account(account,new_user_maps)

          if account.not_synchronized_yet
            account.not_synchronized_yet = false
            account.save
          end
        end
      end
  
      return
    end

    
    def self.log(level,exception,message)
      timestamp = '[' + Time.now.to_s + ']'
      base_message = timestamp + ' [' + level.to_s.upcase + '] ' + message + "\n"
      case level
        when :debug then Rails.logger.debug base_message
        when :info then Rails.logger.info base_message
        when :error then Rails.logger.error base_message + "  " + exception.inspect + "\n" + exception.backtrace.inject(message){|error_message, error_line| error_message << "  " + error_line + "\n"} + "\n" 
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

    
    private
    
      def self.synchronize_account(account, new_user_maps)
        # we synchronize in reverse order of resource dependency: first contacts, then notes and then rings
        ApiOperations::Contacts.synchronize_account(account,new_user_maps)
  
        ApiOperations::Notes.synchronize_account(account,new_user_maps)
  
        ApiOperations::Rings.synchronize_account(account,new_user_maps)
      end
  end
  
end