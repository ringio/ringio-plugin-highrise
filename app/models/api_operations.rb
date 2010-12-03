module ApiOperations
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
  
  def self.rg_contact_to_hr_person(rg_contact,hr_person)
    # we need the hr_person to be already created because we cannot create the ContactData structure
    hr_person.first_name = rg_contact.name
    hr_person.title = rg_contact.title
    hr_person.company_id = (comp = Highrise::Company.find_by_name(rg_contact.business))? comp.id : nil

    # set the contact data
    rg_contact.data.each do |datum|
      case datum.type
        when 'email'
          hr_person.contact_data.email_addresses << (ea = Highrise::Person::ContactData::EmailAddress.new)
          ea.address = datum.value
          case datum.rel
            when 'work' then ea.location = 'Work'
            when 'home' then ea.location = 'Home'
            when 'other' then ea.location = 'Other'
          end
        when 'telephone'
          hr_person.contact_data.phone_numbers << (pn = Highrise::Person::ContactData::PhoneNumber.new)
          pn.number = datum.value
          case datum.rel
            when 'work' then pn.location = 'Work'
            when 'mobile' then pn.location = 'Mobile'
            when 'fax' then pn.location = 'Fax'
            when 'pager' then pn.location = 'Pager'
            when 'home' then pn.location = 'Home'
            when 'other' then pn.location = 'Other'
          end
      end
    end
    
    return
  end

  def self.sync_contacts_rg_to_hr(user_map)
    # get the feed of Ringio contacts since the last timestamp
    rg_contacts_feed = RingioAPI::Feed.find(
      :one,
      :from => RingioAPI::Feed.prefix + "feeds/users/" + user_map.rg_user_id.to_s + "/contacts",
      :params => { :since => user_map.rg_last_timestamp }
    )
    user_map.rg_last_timestamp = rg_contacts_feed.timestamp

    rg_updated_contacts = rg_contacts_feed.updated.map{|updated_id| RingioAPI::Contact.find(updated_id)}
    rg_deleted_contacts_ids = rg_contacts_feed.deleted

    rg_updated_contacts.each do |rg_contact|
      # if the contact was already mapped to Highrise, update it there
      if (cm = ContactMap.find_by_rg_contact_id(rg_contact.id))
debugger # unfinished
      else
      # if the contact is new, create it in Highrise and map it
        new_hr_person = Highrise::Person.new(:first_name => 'Anonymous Ringio Contact')
        new_hr_person.save
        rg_contact_to_hr_person(rg_contact,new_hr_person)
        new_hr_person.save
      end
    end
    
    rg_deleted_contacts_ids.each do |dc_id|
debugger # unfinished
    end
  end
  
  def self.sync_contacts_hr_to_rg(user_map)
    # get only the Highrise people and companies that were created by this user and
    # filter to keep those that were created_at or updated at after the last synchronization datetime
    hr_updated_people = Highrise::Person.find_all_across_pages_since(user_map.hr_last_synchronized_at).reject{|p| p.author_id != user_map.hr_user_id}
    hr_updated_companies = Highrise::Company.find_all_across_pages_since(user_map.hr_last_synchronized_at).reject{|p| p.author_id != user_map.hr_user_id}

    # get deletions of person and companies, mind that author_id is not provided
    hr_deleted_parties = Highrise::Party.deletions_since(user_map.hr_last_synchronized_at)
debugger # unfinished
    user_map.update_hr_last_synchronized_at
  end
  
  # complete synchronization event between Ringio and Highrise
  def self.synchronize
    Account.all.each do |account|
      account.user_maps.each do |user_map|
        self.set_hr_base(user_map)
        self.sync_contacts_rg_to_hr(user_map)
        self.sync_contacts_hr_to_rg(user_map)
        self.empty_hr_base
      end
    end

    return
  end
  
end