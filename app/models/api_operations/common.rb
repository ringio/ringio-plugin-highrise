module ApiOperations

  module Common


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
      ApiOperations::Common.set_hr_base_push user_map

      # TODO: find how to get this faster: from the HTTP header Date from the last Highrise response (ActiveResource does not give access to it)
      # create a fake contact, set timestamp to the created_at in the response and then destroy that fake contact
      timestamp_person = Highrise::Person.new(:first_name => 'Ringio Check')
      timestamp_person.save
      timestamp = timestamp_person.created_at
      timestamp_person.destroy

      ApiOperations::Common.set_hr_base_pop

      timestamp
    end
    
  
    # run a complete synchronization event between Ringio and Highrise
    def self.complete_synchronization

      Account.all.each do |account|
        ApiOperations::Contacts.synchronize_account account

        ApiOperations::Notes.synchronize_account account
debugger
        ApiOperations::Rings.synchronize_account account
      end
  
      return
    end


    private
    
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