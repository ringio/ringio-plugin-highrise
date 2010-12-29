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
      if ApiOperations::Session.locked
        raise 'Highrise Base is currently locked, run ApiOperations::Common.set_hr_base_pop first'        
      else
        self.set_hr_base_basic user_map
      end
    end

    def self.empty_hr_base
      if ApiOperations::Session.locked
        raise 'Highrise Base is currently locked, run ApiOperations::Common.set_hr_base_pop first'        
      else
        self.empty_hr_base_basic
      end
    end
    
    # set Highrise Base, remembering the previous user (MUST be followed by ApiOperations::Common.set_hr_base_pop)
    def self.set_hr_base_push(user_map)
      if ApiOperations::Session.locked
        raise 'Highrise Base is currently locked, run ApiOperations::Common.set_hr_base_pop first'        
      else
        ApiOperations::Session.locked = true
        ApiOperations::Session.previous_user_map = ApiOperations::Session.current_user_map
        self.set_hr_base_basic user_map
      end
    end
    
    # set Highrise Base to the previous user (MUST be preceded by ApiOperations::Common.set_hr_base_push(user_map))
    def self.set_hr_base_pop
      if ApiOperations::Session.locked
        self.set_hr_base_basic(ApiOperations::Session.previous_user_map)
        ApiOperations::Session.locked = false
      else
        raise 'Highrise Base is not currently locked, run ApiOperations::Common.set_hr_base_push(user_map) first'
      end
    end
   
    def self.hr_current_timestamp(user_map)
      timestamp = nil

      if user_map
        ApiOperations::Common.set_hr_base_push user_map
  
        # TODO: find how to get this faster: from the HTTP header Date from the last Highrise response (ActiveResource does not give access to it)
        # create a fake contact, set timestamp to the created_at in the response and then destroy that fake contact
        timestamp_person = Highrise::Person.new(:first_name => 'Ringio Check')
        timestamp_person.save
        timestamp = timestamp_person.created_at
        timestamp_person.destroy
  
        ApiOperations::Common.set_hr_base_pop
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
          self.synchronize_account(account,new_user_maps,account.not_synchronized_yet)
        end
      end
  
      return
    end
    
    def self.log(level,exception,message)
      timestamp = '[' + Time.now.to_s + ']' 
      case level
        when :debug then Rails.logger.debug timestamp + ' ' + message + "\n"
        when :info then Rails.logger.info timestamp + ' ' + message + "\n"
        when :error then Rails.logger.error timestamp + ' ' + message + "\n  " + exception.inspect + "\n" + exception.backtrace.inject(message){|error_message, error_line| error_message << "  " + error_line + "\n"} + "\n" 
        else raise 'Unknown log error level'
      end
    end


    private
    
      def self.synchronize_account(account, new_user_maps, account_not_synchronized_yet)
        # we synchronize in reverse order of resource dependency: first contacts, then notes and then rings
        ApiOperations::Contacts.synchronize_account(account,new_user_maps, account_not_synchronized_yet)
  
        ApiOperations::Notes.synchronize_account(account,new_user_maps, account_not_synchronized_yet)
  
        ApiOperations::Rings.synchronize_account(account,new_user_maps, account_not_synchronized_yet)
      end
      
      def self.set_hr_base_basic(user_map)
        if user_map
          Highrise::Base.site = 'https://' + user_map.account.hr_subdomain + '.highrisehq.com' 
          Highrise::Base.user = user_map.hr_user_token
          ApiOperations::Session.current_user_map = user_map
        else
          self.empty_hr_base_basic
        end
      end
      
      def self.empty_hr_base_basic
        Highrise::Base.site = ''
        Highrise::Base.user = ''
        ApiOperations::Session.current_user_map = nil
      end
    
  end
  
end