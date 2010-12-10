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
      Highrise::Base.site = 'https://' + user_map.account.hr_subdomain + '.highrisehq.com' 
      Highrise::Base.user = user_map.hr_user_token
      return
    end
  
    
    def self.empty_hr_base
      Highrise::Base.site = ''
      Highrise::Base.user = ''
      return
    end
    
    def self.hr_current_timestamp
      # create a fake contact, set timestamp to the created_at in the response and then destroy that fake contact
      timestamp_person = Highrise::Person.new(:first_name => 'Ringio Check')
      timestamp_person.save
      timestamp = timestamp_person.created_at
      timestamp_person.destroy
      timestamp
    end
    
  
    # run a complete synchronization event between Ringio and Highrise
    def self.complete_synchronization

      Account.all.each do |account|

        account.user_maps.each do |user_map|
          self.set_hr_base user_map

          ApiOperations::Contacts.synchronize_user user_map

          user_map.contact_maps.each do |contact_map|
            ApiOperations::Notes.synchronize_contact contact_map
          end

          self.empty_hr_base
        end

      end
  
      return
    end
  
    
  end
  
end