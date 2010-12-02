module ApiOperations
  def self.mails_for_select(rg_account_id)
    mails = []
    (RingioAPI::Feed.find(:one, :from => "/feeds/accounts/" + rg_account_id.to_s + "/users" )).updated.each do |rg_user_id|
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
  
  def self.synchronize   # unfinished
    Account.all.each do |account|

      account.user_maps.each do |user_map|
        self.set_hr_base(user_map)
        
        # get the feed of Ringio contacts since the last timestamp
        rg_contacts_feed = RingioAPI::Feed.find(
          :one,
          :from => "/feeds/users/" + user_map.rg_user_id.to_s + "/contacts",
          :params => { :since => user_map.rg_last_timestamp }
        )
        user_map.rg_last_timestamp = rg_contacts_feed.timestamp

        rg_updated_contacts = rg_contacts_feed.updated.map{|updated_id| RingioAPI::Contact.find(updated_id)}
        rg_deleted_contacts_ids = rg_contacts_feed.deleted

        # get only the Highrise people and companies that were created by this user and
        # filter to keep those that were created_at or updated at after the last synchronization datetime
        hr_updated_people = Highrise::Person.find_all_across_pages_since(user_map.hr_last_synchronized_at).reject{|p| p.author_id != user_map.hr_user_id}
        hr_updated_companies = Highrise::Company.find_all_across_pages_since(user_map.hr_last_synchronized_at).reject{|p| p.author_id != user_map.hr_user_id}

        # get deletions of person and companies, mind that author_id is not provided
        hr_deleted_parties = Highrise::Party.deletions_since(user_map.hr_last_synchronized_at)

        user_map.update_hr_last_synchronized_at

        self.empty_hr_base
      end

    end
  end
  
end