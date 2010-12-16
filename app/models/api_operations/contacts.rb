module ApiOperations

  module Contacts

    def self.synchronize_account(account)

      # get the feed of changed contacts per user of this Ringio account from Ringio
      account_rg_feed = account.rg_contacts_feed
      user_rg_feeds = self.fetch_user_rg_feeds(account_rg_feed,account)
      rg_deleted_contact_ids = account_rg_feed.deleted
      
      # synchronize each user whose contacts have changed
      user_rg_feeds.each do |rg_feed|
        ApiOperations::Common.set_hr_base rg_feed[0]
        self.synchronize_user(rg_feed,rg_deleted_contact_ids)
        ApiOperations::Common.empty_hr_base
      end

      # update timestamps: we must set the timestamp AFTER the changes we made in the synchronization, or
      # we would update those changes again and again in every synchronization (and, to keep it simple, we ignore
      # the changes that other agents may have caused for this account just when we were synchronizing)
      # TODO: ignore only our changes but not the changes made by other agents
      account.rg_contacts_last_timestamp = account.rg_contacts_feed.timestamp
      account.hr_parties_last_synchronized_at = ApiOperations::Common.hr_current_timestamp(account.user_maps.first)
      account.save
      
    end


    private


      # returns an array with each element containing information for each user map:
      # [0] => user map
      # [1] => updated Ringio contacts for this user map
      def self.fetch_user_rg_feeds(account_rg_feed, account)

        account_rg_feed.updated.inject([]) do |user_feeds,rg_contact_id|
          rg_contact = RingioAPI::Contact.find rg_contact_id

          # synchronize only contacts of users already mapped for this account
          if (um = UserMap.find_by_account_id_and_rg_user_id(account.id,rg_contact.owner_id))
            if (um_index = user_feeds.index{|uf| uf[0] == um})
              user_feed = user_feeds[um_index]
              user_feed[1] << rg_contact
            else
              user_feed = []
              user_feed[0] = um
              user_feed[1] = [rg_contact]
              user_feeds << user_feed
            end
          end

          user_feeds
        end
        
      end


      def self.synchronize_user(user_rg_feed, rg_deleted_contacts_ids)
        hr_parties_feed = user_rg_feed[0].hr_parties_feed
        hr_updated_people = hr_parties_feed[0]
        hr_updated_companies = hr_parties_feed[1]
        hr_party_deletions = hr_parties_feed[2]
  
        # give priority to Highrise: discard changes in Ringio to contacts that have been changed in Highrise
        self.purge_contacts(hr_updated_people,hr_updated_companies,hr_party_deletions,user_rg_feed[1],rg_deleted_contacts_ids)

        self.apply_changes_rg_to_hr(user_rg_feed[0],user_rg_feed[1],rg_deleted_contacts_ids)

        self.apply_changes_hr_to_rg(user_rg_feed[0],hr_updated_people,hr_updated_companies,hr_party_deletions)
      end
  
  
      def self.apply_changes_hr_to_rg(user_map, hr_updated_people, hr_updated_companies, hr_party_deletions)
        self.process_updated_parties(user_map, hr_updated_people)
        self.process_updated_parties(user_map, hr_updated_companies)
  
        hr_party_deletions.each do |p_deletion|
          # if the party was already mapped to Ringio, delete it there
          if (cm = ContactMap.find_by_hr_party_id_and_hr_party_type(p_deletion.id,p_deletion.type))
            cm.rg_resource_contact.destroy
            cm.destroy
          end
          # otherwise, don't do anything, because that Highrise party has not been created yet in Ringio
        end
      end
  
  
      def self.process_updated_parties(user_map, hr_updated_parties)
        hr_updated_parties.each do |hr_party|
          rg_contact = self.prepare_rg_contact(user_map,hr_party)
          self.hr_party_to_rg_contact(hr_party,rg_contact)
  
          # if the Ringio contact is saved properly and it didn't exist before, create a new contact map
          new_rg_contact = rg_contact.new?
          if rg_contact.save! && new_rg_contact
            new_cm = ContactMap.new(:user_map_id => user_map.id, :rg_contact_id => rg_contact.id, :hr_party_id => hr_party.id)
            new_cm.hr_party_type = case hr_party
              when Highrise::Person then 'Person'
              when Highrise::Company then 'Company'
              else
                raise 'Unknown Party type'
            end
            new_cm.save!
          end
        end
      end
  
  
      def self.prepare_rg_contact(user_map, hr_party)
        # get the party type
        type = case hr_party
          when Highrise::Person then 'Person'
          when Highrise::Company then 'Company'
          else
            raise 'Unknown Party type'
        end
  
        # if the contact was already mapped to Ringio, we must update it there
        if (cm = ContactMap.find_by_hr_party_id_and_hr_party_type(hr_party.id,type))
          rg_contact = cm.rg_resource_contact
        else
        # if the contact is new, we must create it in Ringio
          # in Ringio (unlike in Highrise) we don't have one token per user, so we have to specify the owner of the new contact
          rg_contact = RingioAPI::Contact.new(:owner_id => user_map.rg_user_id)
        end
        rg_contact
      end


      def self.update_hr_person_name(hr_person,name)
        # update name in Highrise to avoid duplication in next synchronization
        hr_person.first_name = name
        hr_person.last_name = ''
        hr_person.save
      end


      def self.hr_party_to_rg_contact(hr_party, rg_contact)
        # note: we need the Highrise party to be already created because we cannot create the ContactData structure
        case hr_party
          when Highrise::Person
            if hr_party.first_name.present?
              if hr_party.last_name.present?
                rg_contact.name = hr_party.first_name + ' ' + hr_party.last_name
                self.update_hr_person_name(hr_party,rg_contact.name)
              else
                rg_contact.name = hr_party.first_name
              end
            elsif hr_party.last_name.present?
              rg_contact.name = hr_party.last_name
              self.update_hr_person_name(hr_party,rg_contact.name)
            else
              rg_contact.name = 'Anonymous Highrise Contact'
            end
            rg_contact.title = hr_party.title ? hr_party.title : ''
            begin
              comp = Highrise::Company.find(hr_party.company_id)
            rescue ActiveResource::ResourceNotFound
            end
            rg_contact.business = comp ? comp.name : ''
          when Highrise::Company
            rg_contact.name = hr_party.name ? hr_party.name : 'Anonymous Highrise Contact'
          else
            raise 'Unknown Party type'
        end
  
        # clean the contact data structure of the updated Ringio contact
        if rg_contact.new?
          rg_contact.data = Array.new
        else
          # make sure that the corresponding data is empty (though Ringio API does not allow deletion of data) in the Ringio contact
          # (the corresponding data is the data that would have been synchronized from Ringio to Highrise if it existed)
          rg_contact.data.each do |cd|
            case cd.type
              when 'email' then cd = nil
              when 'telephone' then cd = nil
            end
          end
        end

        # TODO: refactor to move repeated structures to a method
        if hr_party.contact_data.present?
          # set the email addresses
          hr_party.contact_data.email_addresses.each do |ea|
            rg_contact.data << (cd = RingioAPI::Contact::Datum.new)
            cd.value = ea.address
            cd.is_primary = nil
            cd.rel = case ea.location
              when 'Work' then 'work'
              when 'Home' then 'home'
              when 'Other' then 'other'
              else 'other'
            end
            cd.type = 'email'
          end
  
          # set the phone numbers
          hr_party.contact_data.phone_numbers.each do |pn|
            rg_contact.data << (cd = RingioAPI::Contact::Datum.new)
            cd.value = pn.number
            cd.is_primary = nil
            cd.rel = case pn.location
              when 'Work' then 'work'
              when 'Mobile' then 'mobile'
              when 'Fax' then 'fax'
              when 'Pager' then 'pager'
              when 'Home' then 'home'
              when 'Other' then 'other'
              else 'other'
            end
            cd.type = 'telephone'
          end
          
          # set the IM data
          hr_party.contact_data.instant_messengers.each do |im|
            if d_index = rg_contact.data.index{|cd| (cd.type == 'im') && (cd.value == (im.address + ' in ' + im.protocol))}
              cd = rg_contact.data[d_index]
            else
              rg_contact.data << (cd = RingioAPI::Contact::Datum.new)
              cd.value = im.address + ' in ' + im.protocol
              cd.is_primary = nil
            end
            cd.rel = case im.location
              when 'Work' then 'work'
              when 'Personal' then 'home'
              when 'Other' then 'other'
              else 'other'
            end
            cd.type = 'im'
          end
  
          # set the twitter accounts
          hr_party.contact_data.twitter_accounts.each do |ta|
            hr_twitter_url = 'http://twitter.com/' + ta.username
            if d_index = rg_contact.data.index{|cd| (cd.type == 'website') && (cd.value == hr_twitter_url)}
              cd = rg_contact.data[d_index]
            else
              rg_contact.data << (cd = RingioAPI::Contact::Datum.new)
              cd.value = hr_twitter_url
              cd.is_primary = nil
            end
            cd.rel = case ta.location
              when 'Personal' then 'home'
              when 'Business' then 'work'
              when 'Other' then 'other'
              else 'other'
            end
            cd.type = 'website'
          end
          
          # set the addresses
          hr_party.contact_data.addresses.each do |ad|
            full_address = ad.street + ' ' + ad.city + ' ' + ad.state + ' ' + ad.zip + ' ' + ad.country
            if d_index = rg_contact.data.index{|cd| (cd.type == 'address') && (cd.value == full_address)}
              cd = rg_contact.data[d_index]
            else
              rg_contact.data << (cd = RingioAPI::Contact::Datum.new)
              cd.value = full_address
              cd.is_primary = nil
            end
            cd.rel = case ad.location
              when 'Work' then 'work'
              when 'Home' then 'home'
              when 'Other' then 'other'
              else 'other'
            end
            cd.type = 'address'
          end

        end
        
        # set the website as the URL for the Highrise party
        url_hr_contact = Highrise::Base.site.to_s + 'parties/' + hr_party.id.to_s + '-' + rg_contact.name.downcase.gsub(' ','-')
        if d_index = rg_contact.data.index{|cd| (cd.type == 'website') && (cd.value == url_hr_contact)}
          cd = rg_contact.data[d_index]
        else
          rg_contact.data << (cd = RingioAPI::Contact::Datum.new)
          cd.value = url_hr_contact
          cd.is_primary = nil
        end
        cd.rel = 'other'
        cd.type = 'website'
      end
  
  
      def self.apply_changes_rg_to_hr(user_map, rg_updated_contacts, rg_deleted_contacts_ids)
        rg_updated_contacts.each do |rg_contact|
          # if the contact was already mapped to Highrise, update it there
          if (cm = ContactMap.find_by_rg_contact_id(rg_contact.id))
            hr_party = cm.hr_resource_party
            self.rg_contact_to_hr_party(rg_contact,hr_party)
          else
          # if the contact is new, create it in Highrise (always as a Person, Ringio GUI does not allow creating a Company) and map it
            hr_party = Highrise::Person.new
            self.rg_contact_to_hr_party(rg_contact,hr_party)
          end
          
          # if the Highrise party is saved properly and it didn't exist before, create a new contact map
          new_hr_party = hr_party.new?
          if hr_party.save! && new_hr_party
            new_cm = ContactMap.new(:user_map_id => user_map.id, :rg_contact_id => rg_contact.id, :hr_party_id => hr_party.id)
            new_cm.hr_party_type = case hr_party
              when Highrise::Person then 'Person'
              when Highrise::Company then 'Company'
              else
                raise 'Unknown Party type'
            end
            new_cm.save!
          end
        end
        
        rg_deleted_contacts_ids.each do |dc_id|
          # if the contact was already mapped to Highrise, delete it there
          if (cm = ContactMap.find_by_rg_contact_id(dc_id))
            hr_party = cm.hr_resource_party
            hr_party.destroy
            cm.destroy
          end
          # otherwise, don't do anything, because that Ringio contact has not been created yet in Highrise
        end
      end
  
  
      def self.purge_contacts(hr_updated_people, hr_updated_companies, hr_party_deletions, rg_updated_contacts, rg_deleted_contacts_ids)
  
        # delete duplicated changes for Highrise updated people
        hr_updated_people.each do |person|
          if (cm = ContactMap.find_by_hr_party_id_and_hr_party_type(person.id,'Person'))
            self.delete_rg_duplicated_changes(cm.rg_contact_id,rg_updated_contacts,rg_deleted_contacts_ids)
          end
        end
        
        # delete duplicated changes for Highrise updated companies
        hr_updated_companies.each do |company|
          if (cm = ContactMap.find_by_hr_party_id_and_hr_party_type(company.id,'Company'))
            self.delete_rg_duplicated_changes(cm.rg_contact_id,rg_updated_contacts,rg_deleted_contacts_ids)
          end
        end
        
        # delete duplicated changes for Highrise deleted parties
        hr_party_deletions.each do |p_deletion|
          if (cm = ContactMap.find_by_hr_party_id_and_hr_party_type(p_deletion.id,p_deletion.type))
            self.delete_rg_duplicated_changes(cm.rg_contact_id,rg_updated_contacts,rg_deleted_contacts_ids)
          end
        end

      end
  
  
      def self.delete_rg_duplicated_changes(rg_contact_id, rg_updated_contacts, rg_deleted_contacts_ids)
        rg_updated_contacts.delete_if{|c| c.id == rg_contact_id}
        rg_deleted_contacts_ids.delete_if{|c_id| c_id == rg_contact_id}      
      end
  
        
      def self.rg_contact_to_hr_party(rg_contact, hr_party)

        case hr_party
          when Highrise::Person
            hr_party.first_name = rg_contact.name.present? ? rg_contact.name : 'Anonymous Ringio Contact'
            hr_party.title = rg_contact.title ? rg_contact.title : ''
            begin
              comp = Highrise::Company.find_by_name(rg_contact.business)
            rescue ActiveResource::ResourceNotFound
            end
            hr_party.company_id = comp ? comp.id : nil
          when Highrise::Company
            hr_party.name = rg_contact.name ? rg_contact.name : 'Anonymous Ringio Contact'
          else
            raise 'Unknown Party type'
        end
    
        # clean the contact data structure of the updated Highrise contact
        if hr_party.new?
          hr_party.contact_data = Highrise::Person::ContactData.new
          hr_party.contact_data.email_addresses = Array.new
          hr_party.contact_data.phone_numbers = Array.new
        else
          # make sure that the corresponding data is empty (or deleted) in the Highrise contact
          # (the corresponding data is the data that would have been synchronized from Highrise to Ringio if it existed)
          hr_party.contact_data.email_addresses.each{|ea| ea.id = -ea.id}
          hr_party.contact_data.phone_numbers.each{|pn| pn.id = -pn.id}
          hr_party.contact_data.instant_messengers.each{|im| im.id = -im.id}
          hr_party.contact_data.twitter_accounts.each{|ta| ta.id = -ta.id}
          hr_party.contact_data.addresses.each{|ad| ad.id = -ad.id}
        end
    
        if rg_contact.data.present?

          # set the contact data
          # TODO: refactor to move repeated structures to a method
          rg_contact.data.each do |datum|
            case datum.type
              when 'email'
                hr_party.contact_data.email_addresses << (ea = Highrise::Person::ContactData::EmailAddress.new)
                ea.address = datum.value
                ea.location = case datum.rel
                  when 'work' then 'Work'
                  when 'home' then 'Home'
                  when 'other' then 'Other'
                  else 'Other'
                end
              when 'telephone'
                hr_party.contact_data.phone_numbers << (pn = Highrise::Person::ContactData::PhoneNumber.new)
                pn.number = datum.value
                pn.location = case datum.rel
                  when 'work' then 'Work'
                  when 'mobile' then 'Mobile'
                  when 'fax' then 'Fax'
                  when 'pager' then 'Pager'
                  when 'home' then 'Home'
                  when 'other' then 'Other'
                  else 'Other'
                end
            end
          end
        end

      end


  end

end