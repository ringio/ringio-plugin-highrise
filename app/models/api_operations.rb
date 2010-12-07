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
  

  # complete synchronization event between Ringio and Highrise
  def self.synchronize
    Account.all.each do |account|
      account.user_maps.each do |user_map|
        self.set_hr_base(user_map)
        
        # get the feed of changed contacts both in Ringio and Highrise
        rg_contacts_feed = user_map.rg_contacts_feed
        rg_updated_contacts_ids = rg_contacts_feed.updated
        rg_deleted_contacts_ids = rg_contacts_feed.deleted

        hr_parties_feed = user_map.hr_parties_feed
        hr_updated_people = hr_parties_feed[0]
        hr_updated_companies = hr_parties_feed[1]
        hr_party_deletions = hr_parties_feed[2]

        # give priority to Highrise: discard changes in Ringio to contacts that have been changed in Highrise
        self.purge_contacts(hr_updated_people,hr_updated_companies,hr_party_deletions,rg_updated_contacts_ids,rg_deleted_contacts_ids)

        self.apply_changes_rg_to_hr(rg_updated_contacts_ids,rg_deleted_contacts_ids)
        
        self.apply_changes_hr_to_rg(user_map,hr_updated_people,hr_updated_companies,hr_party_deletions)

        self.empty_hr_base
      end
    end

    return
  end

  
  private


    def self.apply_changes_hr_to_rg(user_map,hr_updated_people,hr_updated_companies,hr_party_deletions)
      self.process_updated_parties(hr_updated_people)
      self.process_updated_parties(hr_updated_companies)

      hr_party_deletions.each do |p_deletion|
        # if the party was already mapped to Ringio, delete it there
        if (cm = ContactMap.find_by_party_id_and_party_type(p_deletion.id,p_deletion.type))
          cm.rg_resource_contact.destroy
        end
        # otherwise, don't do anything, because that Highrise party has not been created yet in Ringio
      end
    end


    def self.process_updated_parties(hr_updated_parties)
      hr_updated_parties.each do |hr_party|
        rg_contact = self.prepare_rg_contact(user_map,hr_party)
        self.hr_party_to_rg_contact(hr_party,rg_contact)
        rg_contact.save
      end
    end


    def self.prepare_rg_contact(user_map,hr_party)
      # get the party type
      type = case hr_party.class
        when 'Highrise::Person' then 'Person'
        when 'Highrise::Company' then 'Company'
        else
          raise 'Unknown Party type'
      end

      # if the contact was already mapped to Ringio, we must update it there
      if (cm = ContactMap.find_by_party_id_and_party_type(hr_party.id,type))
        rg_contact = cm.rg_resource_contact
      else
      # if the contact is new, we must create it in Ringio
        # in Ringio (unlike in Highrise) we don't have one token per user, so we have to specify the owner of the new contact
        rg_contact = RingioAPI::Contact.new(:owner_id => user_map.rg_user_id) 
      end
    end


    def self.hr_party_to_rg_contact(hr_party,rg_contact)
      # note: we need the Highrise party to be already created because we cannot create the ContactData structure
      case hr_party.class
        when 'Highrise::Person'
          if hr_party.first_name
            if hr_party.last_name
              rg_contact.name = hr_party.first_name + ' ' + hr_party.last_name              
            else
              rg_contact.name = hr_party.first_name
            end
          elsif hr_party.last_name
            rg_contact.name = hr_party.last_name
          else
            rg_contact.name = 'Anonymous Highrise Contact'
          end
          rg_contact.title = hr_party.title
          rg_contact.business = (comp = Highrise::Company.find(hr_party.company_id))? comp.name : nil
        when 'Highrise::Company'
          rg_contact.name = hr_party.name ? hr_party.name : 'Anonymous Highrise Contact'
        else
          raise 'Unknown Party type'
      end

      if hr_party.contact_data
        # if the Ringio contact is new, prepare the contact data structure
        rg_contact.data = Array.new if rg_contact.new?
debugger
        # set the email addresses
        hr_party.contact_data.email_addresses.each do |ea|
          unless rg_contact.data.index{|cd| cd.value == ea.address}
            rg_contact.data << (cd = RingioAPI::Contact::Datum.new)
            cd.value = ea.address
  
            cd.rel = case ea.location
              when 'Work' then ea.location = 'work'
              when 'Home' then ea.location = 'home'
              when 'Other' then ea.location = 'other'
            end
          end
        end

        # set the phone numbers
        hr_party.contact_data.phone_numbers.each do |pn|
          rg_contact.data << (cd = RingioAPI::Contact::Datum.new)
          cd.value = pn.number

          cd.rel = case pn.location
            when 'Work' then 'work'
            when 'Mobile' then 'mobile'
            when 'Fax' then 'fax'
            when 'Pager' then 'pager'
            when 'Home' then 'home'
            when 'Other' then 'other'
          end
        end
      end
      
    end

  
    def self.apply_changes_rg_to_hr(rg_updated_contacts_ids,rg_deleted_contacts_ids)
      rg_updated_contacts_ids.each do |rg_contact_id|
        # if the contact was already mapped to Highrise, update it there
        if (cm = ContactMap.find_by_rg_contact_id(rg_contact_id))
          hr_party = cm.hr_resource_party
        else
        # if the contact is new, create it in Highrise (always as a Person, Ringio GUI does not allow creating a Company) and map it
          hr_party = Highrise::Person.new
        end
        
        self.rg_contact_to_hr_party(cm.rg_resource_contact,hr_party)
        hr_party.save        
      end
      
      rg_deleted_contacts_ids.each do |dc_id|
        # if the contact was already mapped to Highrise, delete it there
        if (cm = ContactMap.find_by_rg_contact_id(dc_id))
          hr_party = cm.hr_resource_party
          hr_party.destroy
        end
        # otherwise, don't do anything, because that Ringio contact has not been created yet in Highrise
      end
    end


    def self.purge_contacts(hr_updated_people,hr_updated_companies,hr_party_deletions,rg_updated_contacts_ids,rg_deleted_contacts_ids)

      # delete duplicated changes for Highrise updated people
      hr_updated_people.map{|p| p.id}.each do |person_id|
        if (cm = ContactMap.find_by_hr_party_id_and_hr_party_type(person_id,'Person'))
          self.delete_rg_duplicated_changes(cm.rg_contact_id,rg_updated_contacts_ids,rg_deleted_contacts_ids)
        end
      end
      
      # delete duplicated changes for Highrise updated companies
      hr_updated_companies.map{|p| p.id}.each do |company_id|
        if (cm = ContactMap.find_by_hr_party_id_and_hr_party_type(company_id,'Company'))
          self.delete_rg_duplicated_changes(cm.rg_contact_id,rg_updated_contacts_ids,rg_deleted_contacts_ids)
        end
      end
      
      # delete duplicated changes for Highrise deleted parties
      hr_party_deletions.each do |p_deletion|
        if (cm = ContactMap.find_by_hr_party_id_and_hr_party_type(p_deletion.id,p_deletion.type))
          self.delete_rg_duplicated_changes(cm.rg_contact_id,rg_updated_contacts_ids,rg_deleted_contacts_ids)
        end
      end
    end


    def self.delete_rg_duplicated_changes(cm_rg_id,rg_updated_contacts_ids,rg_deleted_contacts_ids)
      rg_updated_contacts_ids.delete_if{|c_id| c_id == cm_rg_id}
      rg_deleted_contacts_ids.delete_if{|c_id| c_id == cm_rg_id}      
    end

      
    def self.rg_contact_to_hr_party(rg_contact,hr_party)
      case hr_party.class
        when 'Highrise::Person'
          hr_party.first_name = rg_contact.name ? rg_contact.name : 'Anonymous Ringio Contact'
          hr_party.title = rg_contact.title
          hr_party.company_id = (comp = Highrise::Company.find_by_name(rg_contact.business))? comp.id : nil
        when 'Highrise::Company'
          hr_party.name = rg_contact.name ? rg_contact.name : 'Anonymous Ringio Contact'
        else
          raise 'Unknown Party type'
      end
  
      if rg_contact.data

        # if the Highrise party is new, prepare the ContactData structure
        if hr_party.new?
          hr_party.contact_data = Highrise::Person::ContactData.new
          hr_party.contact_data.email_addresses = Array.new
          hr_party.contact_data.phone_numbers = Array.new
        end

        # set the contact data
        rg_contact.data.each do |datum|
          case datum.type
            when 'email'
debugger # TODO: treat the case where the address or the phone exists with different location
              unless hr_party.contact_data.email_addresses.index{|ea| ea.address == datum.value}
                hr_party.contact_data.email_addresses << (ea = Highrise::Person::ContactData::EmailAddress.new)
                ea.address = datum.value
                ea.location = case datum.rel
                  when 'work' then 'Work'
                  when 'home' then 'Home'
                  when 'other' then 'Other'
                end
              end
            when 'telephone'
              unless hr_party.contact_data.phone_numbers.index{|pn| pn.number == datum.value}
                hr_party.contact_data.phone_numbers << (pn = Highrise::Person::ContactData::PhoneNumber.new)
                pn.number = datum.value
                pn.location = case datum.rel
                  when 'work' then 'Work'
                  when 'mobile' then 'Mobile'
                  when 'fax' then 'Fax'
                  when 'pager' then 'Pager'
                  when 'home' then 'Home'
                  when 'other' then 'Other'
                end
              end
          end
        end
      end
      
      return
    end
  
  
  
end