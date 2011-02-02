module ApiOperations

  module Contacts

    RG_CLIENT_GROUP = "3"

    def self.synchronize_account(account, new_user_maps)
      ApiOperations::Common.log(:debug,nil,"Started the synchronization of the contacts of the account with id = " + account.id.to_s)
      
      # run a synchronization just for each new user map
      new_user_maps.each do |um|
        self.synchronize_account_process(account,um)
      end

      # run a normal complete synchronization
      self.synchronize_account_process(account,nil) unless account.not_synchronized_yet

      self.update_timestamps account

      ApiOperations::Common.log(:debug,nil,"Finished the synchronization of the contacts of the account with id = " + account.id.to_s)
    end


    private

      def self.synchronize_account_process(account, user_map)
        # if there is a new user map
        if user_map
          ApiOperations::Common.log(:debug,nil,"Started contact synchronization of the new user map with id = " + user_map.id.to_s + " and account with id = " + account.id.to_s)

          begin
            # get the feed of all contacts for this new user map of this Ringio account from Ringio
            user_rg_feed = self.fetch_individual_user_rg_feed user_map
            # as it is the first synchronization for this user map, we are not interested in deleted contacts
            rg_deleted_contact_ids = []
          rescue Exception => e
            ApiOperations::Common.log(:error,e,"\nProblem fetching the contacts of the new user map with id = " + user_map.id.to_s + " and account with id = " + account.id.to_s)
          end

          begin
            self.synchronize_user(true,user_map,user_rg_feed,rg_deleted_contact_ids)
          rescue Exception => e
            ApiOperations::Common.log(:error,e,"\nProblem synchronizing the contacts of the new user map with id = " + um.id.to_s)
          end
          
          ApiOperations::Common.log(:debug,nil,"Finished contact synchronization of the new user map with id = " + user_map.id.to_s + " and account with id = " + account.id.to_s)
        else
          begin
            # get the feed of changed contacts per user of this Ringio account from Ringio
            ApiOperations::Common.log(:debug,nil,"Getting the changed contacts of the account with id = " + account.id.to_s)
            account_rg_feed = account.rg_contacts_feed
            user_rg_feeds = self.fetch_user_rg_feeds(account_rg_feed,account)
            rg_deleted_contact_ids = account_rg_feed.deleted
          rescue Exception => e
            ApiOperations::Common.log(:error,e,"\nProblem fetching the changed contacts of the account with id = " + account.id.to_s)
          end
          self.synchronize_users(account,user_rg_feeds,rg_deleted_contact_ids)
        end
      end


      def self.synchronize_users(account, user_rg_feeds, rg_deleted_contact_ids)
        begin
          # synchronize the contacts owned by every user of this account
          account.user_maps.each do |um|
            begin
              user_rg_feed = (rg_f_index = user_rg_feeds.index{|urf| urf[0] == um})? user_rg_feeds[rg_f_index] : [um,[]]
              self.synchronize_user(false,um,user_rg_feed,rg_deleted_contact_ids)
            rescue Exception => e
              ApiOperations::Common.log(:error,e,"\nProblem synchronizing the contacts of the user map with id = " + um.id.to_s)
            end
          end
        rescue Exception => e
          ApiOperations::Common.log(:error,e,"\nProblem synchronizing the contacts")
        end
      end


      def self.update_timestamps(account)
        begin
          # update timestamps: we must set the timestamp AFTER the changes we made in the synchronization, or
          # we would update those changes again and again in every synchronization (and, to keep it simple, we ignore
          # the changes that other agents may have caused for this account just when we were synchronizing)
          # TODO: ignore only our changes but not the changes made by other agents

          rg_timestamp = account.rg_contacts_feed.timestamp
          if rg_timestamp && rg_timestamp > account.rg_contacts_last_timestamp
            account.rg_contacts_last_timestamp = rg_timestamp
          else
            ApiOperations::Common.log(:error,nil,"\nProblem with the Ringio contacts timestamp of the account with id = " + account.id.to_s)
          end
          
          hr_timestamp = ApiOperations::Common.hr_current_timestamp account
          if hr_timestamp && hr_timestamp > account.hr_parties_last_synchronized_at
            account.hr_parties_last_synchronized_at = hr_timestamp
          else
            ApiOperations::Common.log(:error,nil,"\nProblem with the Highrise parties timestamp of the account with id = " + account.id.to_s)
          end
          
          account.save!
        rescue Exception => e
          ApiOperations::Common.log(:error,e,"\nProblem updating the contact synchronization timestamps of the account with id = " + account.id.to_s)
        end        
      end


      # returns an array with each element containing information for each user map:
      # [0] => user map
      # [1] => updated Ringio contacts for this user map
      def self.fetch_user_rg_feeds(account_rg_feed, account)
        account_rg_feed.updated.inject([]) do |user_feeds,rg_contact_id|
          rg_contact = RingioAPI::Contact.find rg_contact_id

          # synchronize only contacts of users already mapped for this account
          if (um = UserMap.find_by_account_id_and_rg_user_id(account.id,rg_contact.owner_id))
            if (um_index = user_feeds.index{|uf| uf[0] == um})
              user_feeds[um_index][1] << rg_contact
            else
              user_feeds << [um,[rg_contact]]
            end
          end

          user_feeds
        end
      end
      
      # behaves like self.fetch_user_rg_feeds but just for the element of the array for this user map
      def self.fetch_individual_user_rg_feed(user_map)
        updated_rg_contacts = user_map.all_rg_contacts_feed.updated.inject([]) do |u_rg_contacts,rg_contact_id|
          rg_contact = RingioAPI::Contact.find rg_contact_id

          # synchronize only contacts that belong to this user map
          if user_map.rg_user_id.to_s == rg_contact.owner_id
            u_rg_contacts << rg_contact
          end

          u_rg_contacts
        end
        
        [user_map, updated_rg_contacts]
      end


      def self.synchronize_user(is_new_user, user_map, user_rg_feed, rg_deleted_contacts_ids)
        ApiOperations::Common.log(:debug,nil,"Started applying contact changes for the user map with id = " + user_map.id.to_s)
        ApiOperations::Common.set_hr_base user_map

        hr_parties_feed = user_map.hr_parties_feed is_new_user
        hr_updated_people = hr_parties_feed[0]
        hr_updated_companies = hr_parties_feed[1]
        hr_party_deletions = is_new_user ? [] : hr_parties_feed[2]

        if user_rg_feed.present? || rg_deleted_contacts_ids.present? || hr_updated_people.present? || hr_updated_companies.present? || hr_party_deletions.present?
          self.merge_changes(hr_updated_people,hr_updated_companies,hr_party_deletions,user_rg_feed,rg_deleted_contacts_ids)
  
          # apply changes from Ringio to Highrise
          self.update_rg_to_hr(user_map,user_rg_feed)
          self.delete_rg_to_hr(user_map,rg_deleted_contacts_ids) unless is_new_user

          # apply changes from Highrise to Ringio
          self.update_hr_to_rg(user_map,hr_updated_people)
          self.update_hr_to_rg(user_map,hr_updated_companies)
          self.delete_hr_to_rg(user_map,hr_party_deletions) unless is_new_user
        end

        ApiOperations::Common.empty_hr_base
        ApiOperations::Common.log(:debug,nil,"Finished applying contact changes for the user map with id = " + user_map.id.to_s)
      end
  
  
      def self.delete_hr_to_rg(user_map, hr_party_deletions)
        hr_party_deletions.each do |p_deletion|
          begin
            ApiOperations::Common.log(:debug,nil,"Started applying deletion from Highrise to Ringio of the party with Highrise id = " + p_deletion.id.to_s)
            
            # if the party was already mapped to Ringio for this user map, delete it there
            if (cm = ContactMap.find_by_user_map_id_and_hr_party_id_and_hr_party_type(user_map.id,p_deletion.id,p_deletion.type))
              begin
                rg_contact = cm.rg_resource_contact
                rg_contact.destroy
              rescue ActiveResource::ResourceNotFound
                # the contact was also deleted in Ringio                                
              end
              cm.destroy
            end
            # otherwise, don't do anything, because that Highrise party has not been created yet in Ringio
  
            ApiOperations::Common.log(:debug,nil,"Finished applying deletion from Highrise to Ringio of the party with Highrise id = " + p_deletion.id.to_s)
          rescue Exception => e
            ApiOperations::Common.log(:error,e,"Problem applying deletion from Highrise to Ringio of the party with Highrise id = " + p_deletion.id.to_s)
          end
        end
      end
  
  
      def self.update_hr_to_rg(user_map, hr_updated_parties)
        hr_updated_parties.each do |hr_party|
          begin
            ApiOperations::Common.log(:debug,nil,"Started applying update from Highrise to Ringio of the party with Highrise id = " + hr_party.id.to_s)

            rg_contact = self.prepare_rg_contact(user_map,hr_party)
            self.hr_party_to_rg_contact(hr_party,rg_contact,user_map)
    
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

            ApiOperations::Common.log(:debug,nil,"Finished applying update from Highrise to Ringio of the party with Highrise id = " + hr_party.id.to_s)
          rescue Exception => e
            ApiOperations::Common.log(:error,e,"Problem applying update from Highrise to Ringio of the party with Highrise id = " + hr_party.id.to_s)
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


      def self.hr_party_to_rg_contact(hr_party, rg_contact, user_map)
        # note: we need the Highrise party to be already created because we cannot create the ContactData structure
        case hr_party
          when Highrise::Person
            if hr_party.first_name.present?
              if hr_party.last_name.present?
                rg_contact.name = hr_party.first_name + ' ' + hr_party.last_name
              else
                rg_contact.name = hr_party.first_name
              end
            elsif hr_party.last_name.present?
              rg_contact.name = hr_party.last_name
            else
              rg_contact.name = 'Anonymous Highrise Contact'
            end
            rg_contact.title = hr_party.title ? hr_party.title : ''
            begin
              comp = hr_party.company_id ? Highrise::Company.find(hr_party.company_id) : nil
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
          # make sure that the corresponding data is empty in the Ringio contact.
          # (the corresponding data is the data that would have been synchronized from Ringio to Highrise if it existed)
          # Ringio API does not allow direct deletion of data, it assumes deletion if data is missing.
          rg_contact.data.each do |cd|
            case cd.type
              when 'email' then rg_contact.data.delete cd
              when 'telephone' then rg_contact.data.delete cd
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
              cd.value = im.address + ' in ' + (im.protocol.present? ? im.protocol : '')
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
            full_address = ''
            full_address << (ad.street + ' ')  if ad.street.present? 
            full_address << (ad.city + ' ') if ad.city.present?
            full_address << (ad.state + ' ') if ad.state.present?
            full_address << (ad.zip + ' ') if ad.zip.present?
            full_address << (ad.country + ' ') if ad.country.present?

            # remove the trailing white space
            full_address = full_address[0,full_address.length - 1] if full_address.present?
            
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
        root_resource_part = (Highrise::Base.site.to_s[Highrise::Base.site.to_s.length - 1] == '/') ? 'parties/' : '/parties/'
        url_hr_contact = Highrise::Base.site.to_s + root_resource_part + hr_party.id.to_s + '-' + rg_contact.name.downcase.gsub(' ','-')
        if d_index = rg_contact.data.index{|cd| (cd.type == 'website') && (cd.value == url_hr_contact)}
          cd = rg_contact.data[d_index]
        else
          rg_contact.data << (cd = RingioAPI::Contact::Datum.new)
          cd.value = url_hr_contact
          cd.is_primary = nil
        end
        cd.rel = 'other'
        cd.type = 'website'
        
        # handle visibility:
        #   - if Highrise visible_to is set to Everyone, share the contact in Ringio (need group Clients)
        #   - otherwise, don't share the contact in Ringio (no Client group)
        if (hr_party.visible_to == 'Everyone')
          if rg_contact.attributes['groups'].present?
            rg_contact.groups << RG_CLIENT_GROUP if ! rg_contact.groups.include?(RG_CLIENT_GROUP)
          else
            rg_contact.attributes['groups'] = [RG_CLIENT_GROUP]
          end
        else
          rg_contact.groups.delete(RG_CLIENT_GROUP) if rg_contact.attributes['groups'].present?
        end
      end
  
  
      def self.update_rg_to_hr(user_map, user_rg_feed)
        user_rg_feed[1].each do |rg_contact|
          ApiOperations::Common.log(:debug,nil,"Started applying update from Ringio to Highrise of the contact with Ringio id = " + rg_contact.id.to_s)

          begin
            preparation = self.prepare_hr_party(rg_contact,user_map)
            hr_party = preparation[0]
            is_new_hr_party = preparation[1]

            # if the Highrise party is saved properly and it didn't exist before, create a new contact map
            if hr_party.save! && is_new_hr_party
              new_cm = ContactMap.new(:user_map_id => user_map.id, :rg_contact_id => rg_contact.id, :hr_party_id => hr_party.id)
              new_cm.hr_party_type = case hr_party
                when Highrise::Person then 'Person'
                when Highrise::Company then 'Company'
                else
                  raise 'Unknown Party type'
              end
              new_cm.save!
            end

            ApiOperations::Common.log(:debug,nil,"Finished applying update from Ringio to Highrise of the contact with Ringio id = " + rg_contact.id.to_s)
          rescue Exception => e
            ApiOperations::Common.log(:error,e,"Problem applying update from Ringio to Highrise of the contact with Ringio id = " + rg_contact.id.to_s)
          end
        end
      end


      def self.prepare_hr_party(rg_contact, user_map)
        # if the contact was already mapped to Highrise, update it there
        if (cm = ContactMap.find_by_rg_contact_id(rg_contact.id))
          hr_party = cm.hr_resource_party
          self.rg_contact_to_hr_party(rg_contact,hr_party,user_map)
          is_new_hr_party = false
        else
        # if the contact is new, create it in Highrise (always as a Person, Ringio GUI does not allow creating a Company) and map it
          hr_party = Highrise::Person.new
          self.rg_contact_to_hr_party(rg_contact,hr_party,user_map)
          is_new_hr_party = true
        end

        [hr_party,is_new_hr_party]
      end
  
  
      def self.delete_rg_to_hr(user_map, rg_deleted_contacts_ids)
        rg_deleted_contacts_ids.each do |dc_id|
          begin
            ApiOperations::Common.log(:debug,nil,"Started applying deletion from Ringio to Highrise of the contact with Ringio id = " + dc_id.to_s)
  
            # if the contact was already mapped to Highrise for this user, delete it there
            if (cm = ContactMap.find_by_rg_contact_id_and_user_map_id(dc_id,user_map.id))
              hr_party = cm.hr_resource_party
              hr_party.destroy
              cm.destroy
            end
            # otherwise, don't do anything, because that Ringio contact has not been created yet in Highrise
  
            ApiOperations::Common.log(:debug,nil,"Finished applying deletion from Ringio to Highrise of the contact with Ringio id = " + dc_id.to_s)
          rescue Exception => e
            ApiOperations::Common.log(:error,e,"Problem applying deletion from Ringio to Highrise of the contact with Ringio id = " + dc_id.to_s)
          end
        end
      end
  
      # give priority to Highrise: discard changes in Ringio to contacts that have been changed in Highrise
      # and give priority to deletions from one side over updates from the other side, wherever the deletion comes from  
      def self.merge_changes(hr_updated_people, hr_updated_companies, hr_party_deletions, user_rg_feed, rg_deleted_contacts_ids)
        begin
          # delete duplicated changes for Highrise updated people
          hr_updated_people.each do |person|
            if (cm = ContactMap.find_by_hr_party_id_and_hr_party_type(person.id,'Person'))
              self.delete_rg_duplicated_changes(cm.rg_contact_id,user_rg_feed)
            end
          end
          
          # delete duplicated changes for Highrise updated companies
          hr_updated_companies.each do |company|
            if (cm = ContactMap.find_by_hr_party_id_and_hr_party_type(company.id,'Company'))
              self.delete_rg_duplicated_changes(cm.rg_contact_id,user_rg_feed)
            end
          end
          
          # delete duplicated changes for Highrise deleted parties
          hr_party_deletions.each do |p_deletion|
            if (cm = ContactMap.find_by_hr_party_id_and_hr_party_type(p_deletion.id,p_deletion.type))
              self.delete_rg_duplicated_changes(cm.rg_contact_id,user_rg_feed)
              rg_deleted_contacts_ids.delete_if{|c_id| c_id.to_s == cm.rg_contact_id.to_s}
            end
          end
          
          # delete duplicated changes for Ringio deleted contacts
          rg_deleted_contacts_ids.each do |rg_c_id|
            if (cm = ContactMap.find_by_rg_contact_id(rg_c_id))
              hr_updated_people.delete_if{|p| p.id.to_s == cm.hr_party_id.to_s} if (cm.hr_party_type == 'Person')
              hr_updated_companies.delete_if{|c| c.id.to_s == cm.hr_party_id.to_s} if (cm.hr_party_type == 'Company')
            end
          end
        rescue Exception => e
          ApiOperations::Common.log(:error,e,"\nProblem merging the changes of the contacts")
        end
      end
  
  
      def self.delete_rg_duplicated_changes(rg_contact_id, user_rg_feed)
        if user_rg_feed
          user_rg_feed[1].delete_if{|c| c.id.to_s == rg_contact_id.to_s}
        end
      end


      def self.set_anonymous_person_in_hr(hr_person)
        hr_person.first_name = 'Anonymous Ringio Contact'
        hr_person.last_name = ''        
      end
      
        
      def self.rg_contact_to_hr_party(rg_contact, hr_party, user_map)
        # the author of the Highrise party is set by Highrise as the current authenticated user
        case hr_party
          when Highrise::Person
            if rg_contact.name.present?
              if (name_words = rg_contact.name.split(' ')).present?
                hr_party.first_name = name_words.first
                name_words[0] = ''
                hr_party.last_name = name_words.inject{|total, word| total + ' ' + word}
              else
                self.set_anonymous_person_in_hr(hr_party)      
              end
            else
              self.set_anonymous_person_in_hr(hr_party)
            end
            hr_party.title = rg_contact.title ? rg_contact.title : ''
            comp_id = nil
            if rg_contact.business.present?
              begin
                c_index = (coincidence_companies = Highrise::Company.find(:all, :from => :search, :params => { :term => rg_contact.business })).index{|c| c.name == rg_contact.business}
                comp_id = c_index ? coincidence_companies[c_index].id : nil 
              rescue ActiveResource::ResourceNotFound
              end
            end
            hr_party.company_id = comp_id
          when Highrise::Company
            hr_party.name = rg_contact.name ? rg_contact.name : 'Anonymous Ringio Contact'
          else
            raise 'Unknown Party type'
        end
    
        # clean the contact data structure of the updated Highrise contact
        if hr_party.new?
          # save so that the server creates the contact data structure
          # (we cannot create ourselves the Highrise::Person::ContactData because it is not in the Highrise gem)
          hr_party.save!
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
                if datum.attributes['rel'].present?
                  ea.location = case datum.rel
                    when 'work' then 'Work'
                    when 'home' then 'Home'
                    when 'other' then 'Other'
                    else 'Other'
                  end
                else
                  ea.location = 'Other'
                end
              when 'telephone'
                hr_party.contact_data.phone_numbers << (pn = Highrise::Person::ContactData::PhoneNumber.new)
                pn.number = datum.value
                if datum.attributes['rel'].present?
                  pn.location = case datum.rel
                    when 'work' then 'Work'
                    when 'mobile' then 'Mobile'
                    when 'fax' then 'Fax'
                    when 'pager' then 'Pager'
                    when 'home' then 'Home'
                    when 'other' then 'Other'
                    else 'Other'
                  end
                else
                  pn.location = 'Other' 
                end
            end
          end
        end
        
        # handle visibility:
        #   - if the contact is shared in Ringio (group Client), set Highrise visible_to to Everyone
        #   - otherwise, restrict the visibility in Highrise to the owner of the contact
        if rg_contact.groups.include?(RG_CLIENT_GROUP)
          hr_party.visible_to = 'Everyone'
        else
          hr_party.visible_to = 'Owner'
          hr_party.owner_id = user_map.hr_user_id 
        end
               
      end


  end

end