module ApiOperations

  module Notes

    def self.synchronize_account(account, new_user_maps)
debugger
      ApiOperations::Common.log(:debug,nil,"Started the synchronization of the notes of the account with id = " + account.id.to_s)

      # run a synchronization just for each new user map
      new_user_maps.each do |um|
        self.synchronize_account_process(account,um)
      end
      
      # run a normal complete synchronization
      self.synchronize_account_process(account,nil)

      self.update_timestamps account
      
      ApiOperations::Common.log(:debug,nil,"Finished the synchronization of the notes of the account with id = " + account.id.to_s)
    end


    private

      def self.synchronize_account_process(account, user_map)
        # if there is a new user map
        if user_map
          begin
            # get the feed of changed notes per contact of this Ringio account from Ringio
            ApiOperations::Common.log(:debug,nil,"Getting the changed notes for the new user map with id = " + user_map.id.to_s + " of the account with id = " + account.id.to_s)
            user_rg_feed = self.fetch_individual_user_rg_feed user_map
            # as it is the first synchronization for this user map, we are not interested in deleted notes
            rg_deleted_notes_ids = []
          rescue Exception => e
            ApiOperations::Common.log(:error,e,"\nProblem fetching the changed notes for the new user map with id = " + user_map.id.to_s + " of the account with id = " + account.id.to_s)
          end
          
          begin
            self.synchronize_user user_rg_feed
          rescue Exception => e
            ApiOperations::Common.log(:error,e,"\nProblem synchronizing the contacts of the new user map with id = " + um.id.to_s)
          end
        else
          begin
            # get the feed of changed notes per contact of this Ringio account from Ringio
            ApiOperations::Common.log(:debug,nil,"Getting the changed notes of the account with id = " + account.id.to_s)
            account_rg_feed = account.rg_notes_feed
            user_rg_feeds = self.fetch_user_rg_feeds(account_rg_feed,account)
            rg_deleted_notes_ids = account_rg_feed.deleted
          rescue Exception => e
            ApiOperations::Common.log(:error,e,"\nProblem fetching the changed notes of the account with id = " + account.id.to_s)
          end
    
          self.synchronize_contacts(account,user_rg_feeds,rg_deleted_notes_ids)
        end
      end


      def self.synchronize_user(user_rg_feed)
        begin
          user_map = user_rg_feed[0]
          ApiOperations::Common.set_hr_base user_map
          
          # we have to check all contacts, not only the ones owned by this user,
          # because users can create notes for contacts that are not owned by them
          ContactMap.all.each do |cm|
            begin
              contact_rg_feed = (c_rg_f_index = user_rg_feed[1].index{|contact_rg_feed| contact_rg_feed[0] == cm})? user_rg_feed[1][c_rg_f_index] : nil
              self.synchronize_contact(true,user_map,cm,contact_rg_feed,[])
            rescue Exception => e
              ApiOperations::Common.log(:error,e,"\nProblem synchronizing the notes created by the new user map with id = " + user_map.id.to_s + "\n" + "for the contact map with id = " + cm.id.to_s)
            end          
          end
          
          ApiOperations::Common.empty_hr_base
        rescue Exception => e
          ApiOperations::Common.log(:error,e,"\nProblem synchronizing the notes created by the new user map with id = " + user_map.id.to_s)
        end
      end
    

      def self.update_timestamps(account)
        begin
          # update timestamps: we must set the timestamp AFTER the changes we made in the synchronization, or
          # we would update those changes again and again in every synchronization (and, to keep it simple, we ignore
          # the changes that other agents may have caused for this account just when we were synchronizing)
          # TODO: ignore only our changes but not the changes made by other agents
          account.rg_notes_last_timestamp = account.rg_notes_feed.timestamp
          account.hr_notes_last_synchronized_at = ApiOperations::Common.hr_current_timestamp(account.user_maps.first)
          account.save
        rescue Exception => e
          ApiOperations::Common.log(:error,e,"\nProblem updating the note synchronization timestamps of the account with id = " + account.id.to_s)
        end        
      end
    
    
      def self.synchronize_contacts(account, user_rg_feeds, rg_deleted_notes_ids)
        begin
          # synchronize the notes created by every user of this account
          UserMap.find_all_by_account_id(account.id).each do |um|
            begin
              ApiOperations::Common.set_hr_base um
              
              # we have to check all contacts, not only the ones owned by this user,
              # because users can create notes for contacts that are not owned by them
              ContactMap.all.each do |cm|
                begin
                  user_rg_feed = (u_rg_f_index = user_rg_feeds.index{|urf| urf[0] == um})? user_rg_feeds[u_rg_f_index] : nil
                  contact_rg_feed = user_rg_feed.present? ? ((c_rg_f_index = user_rg_feed[1].index{|contact_rg_feed| contact_rg_feed[0] == cm})? user_rg_feed[1][c_rg_f_index] : nil) : nil
                  self.synchronize_contact(false,um,cm,contact_rg_feed,rg_deleted_notes_ids)
                rescue Exception => e
                  ApiOperations::Common.log(:error,e,"\nProblem synchronizing the notes created by the user map with id = " + um.id.to_s + "\n" + "for the contact map with id = " + cm.id.to_s)
                end          
              end
              
              ApiOperations::Common.empty_hr_base
            rescue Exception => e
              ApiOperations::Common.log(:error,e,"\nProblem synchronizing the notes created by the user map with id = " + um.id.to_s)
            end
          end
        rescue Exception => e
          ApiOperations::Common.log(:error,e,"\nProblem synchronizing the notes")
        end
      end


      # behaves like self.fetch_user_rg_feeds but just for the element of the array for this user map
      def self.fetch_individual_user_rg_feed(user_map)
        user_map.account.rg_notes_feed.updated.inject([user_map,[]]) do |user_feed,rg_note_id|
          rg_note = RingioAPI::Note.find rg_note_id

          # synchronize only notes created by this user
          if user_map.rg_user_id == rg_note.author_id
            # synchronize only notes created for contacts already mapped for this user map
            if (cm = ContactMap.find_by_user_map_id_and_rg_contact_id(user_map.id,rg_note.contact_id))
              if (cf_index = user_feed[1].index{|cf| cf[0] == cm})
                user_feed[1][cf_index][1] << rg_note
              else
                user_feed[1] << [cm,[rg_note]]
              end
            end
          end

          user_feed
        end
      end

      
      # returns an array with each element containing information for each author user map:
      # [0] => author user map
      # [1][i][0] => contact map i
      # [1][i][1] => updated Ringio notes for contact map i and author user map
      def self.fetch_user_rg_feeds(account_rg_feed, account)
        account_rg_feed.updated.inject([]) do |user_feeds,rg_note_id|
          rg_note = RingioAPI::Note.find rg_note_id

          # synchronize only notes created by users already mapped for this account
          if (um = UserMap.find_by_account_id_and_rg_user_id(account.id,rg_note.author_id))
            # synchronize only notes created for contacts already mapped for this account
            if (cm = ContactMap.find_by_rg_contact_id(rg_note.contact_id)) && (cm.user_map.account == account)
              if (uf_index = user_feeds.index{|uf| uf[0] == um})
                if (cf_index = user_feeds[uf_index][1].index{|cf| cf[0] == cm})
                  user_feeds[uf_index][1][cf_index][1] << rg_note
                else
                  user_feeds[uf_index][1] << [cm,[rg_note]]
                end
              else
                user_feeds << [ um , [[cm,[rg_note]]] ]
              end
            end
          end

          user_feeds
        end
      end


      def self.synchronize_contact(individual,author_user_map, contact_map, contact_rg_feed, rg_deleted_notes_ids)
        hr_updated_note_recordings = contact_map.hr_updated_note_recordings individual
        # TODO: get true feeds of deleted notes (currently Highrise does not offer it)
        hr_notes = contact_map.hr_notes

        # get the deleted notes (those that don't appear anymore in the total)
        hr_deleted_notes_ids = individual ? [] : contact_map.note_maps.reject{|nm| hr_notes.index{|hr_n| hr_n.id == nm.hr_note_id}}.map{|nm| nm.hr_note_id}

        # give priority to Highrise: discard changes in Ringio to notes that have been changed in Highrise
        self.purge_notes(hr_updated_note_recordings,hr_deleted_notes_ids,contact_rg_feed,rg_deleted_notes_ids)

        # apply changes from Ringio to Highrise
        self.update_rg_to_hr(author_user_map,contact_map,contact_rg_feed)
        self.delete_rg_to_hr(author_user_map,rg_deleted_notes_ids) unless individual
        
        # apply changes from Highrise to Ringio
        self.update_hr_to_rg(author_user_map,contact_map,hr_updated_note_recordings)
        self.delete_hr_to_rg(author_user_map,hr_deleted_notes_ids) unless individual
      end


      def self.purge_notes(hr_updated_note_recordings, hr_deleted_notes_ids, contact_rg_feed, rg_deleted_notes_ids)
        # delete duplicated changes for Highrise updated notes
        hr_updated_note_recordings.each do |r|
          if (nm = NoteMap.find_by_hr_note_id(r.id))
            self.delete_rg_duplicated_changes(nm.rg_note_id,contact_rg_feed,rg_deleted_notes_ids)
          end
        end
        
        # delete duplicated changes for Highrise deleted notes
        hr_deleted_notes_ids.each do |n_id|
          if (nm = NoteMap.find_by_hr_note_id(n_id))
            self.delete_rg_duplicated_changes(nm.rg_note_id,contact_rg_feed,rg_deleted_notes_ids)
          end
        end
      end


      def self.delete_rg_duplicated_changes(rg_note_id, contact_rg_feed, rg_deleted_notes_ids)
        if contact_rg_feed
          contact_rg_feed[1].delete_if{|n| n.id == rg_note_id}
        end
        rg_deleted_notes_ids.delete_if{|n_id| n_id == rg_note_id}      
      end


      def self.update_hr_to_rg(author_user_map, contact_map, hr_updated_note_recordings)
        hr_updated_note_recordings.each do |hr_note|
          ApiOperations::Common.log(:debug,nil,"Started applying update from Highrise to Ringio of the note with Highrise id = " + hr_note.id.to_s)

          rg_note = self.prepare_rg_note(contact_map,hr_note)
          self.hr_note_to_rg_note(author_user_map,contact_map,hr_note,rg_note)
  
          # if the Ringio note is saved properly and it didn't exist before, create a new note map
          new_rg_note = rg_note.new?
          if rg_note.save! && new_rg_note
            new_nm = NoteMap.new(:contact_map_id => contact_map.id, :author_user_map_id => author_user_map.id, :rg_note_id => rg_note.id, :hr_note_id => hr_note.id)
            new_nm.save!
          end

          ApiOperations::Common.log(:debug,nil,"Finished applying update from Highrise to Ringio of the note with Highrise id = " + hr_note.id.to_s)
        end
      end


      def self.delete_hr_to_rg(author_user_map, hr_deleted_notes_ids)
        hr_deleted_notes_ids.each do |n_id|
          ApiOperations::Common.log(:debug,nil,"Started applying deletion from Highrise to Ringio of the note with Highrise id = " + n_id.to_s)
          
          # if the note was already mapped to Ringio for this author user map, delete it there
          if (nm = NoteMap.find_by_author_user_map_id_and_hr_note_id(author_user_map.id,n_id))
            nm.rg_resource_note.destroy
            nm.destroy
          end
          # otherwise, don't do anything, because that Highrise party has not been created yet in Ringio
          
          ApiOperations::Common.log(:debug,nil,"Finished applying deletion from Highrise to Ringio of the note with Highrise id = " + n_id.to_s)
        end        
      end


      def self.prepare_rg_note(contact_map, hr_note)
        # if the note was already mapped to Ringio, we must update it there
        if (nm = NoteMap.find_by_hr_note_id(hr_note.id))
          rg_note = nm.rg_resource_note
        else
        # if the note is new, we must create it in Ringio
          rg_note = RingioAPI::Note.new
        end
        rg_note
      end


      def self.hr_note_to_rg_note(author_user_map, contact_map, hr_note, rg_note)
        rg_note.author_id = author_user_map.rg_user_id
        rg_note.contact_id = contact_map.rg_contact_id
        rg_note.body =  hr_note.body  
      end


      def self.update_rg_to_hr(author_user_map, contact_map, contact_rg_feed)
        if contact_rg_feed
          contact_rg_feed[1].each do |rg_note|
            ApiOperations::Common.log(:debug,nil,"Started applying update from Ringio to Highrise of the note with Ringio id = " + rg_note.id.to_s)

            # if the note was already mapped to Highrise, update it there
            if (nm = NoteMap.find_by_rg_note_id(rg_note.id))
              hr_note = nm.hr_resource_note
              self.rg_note_to_hr_note(contact_map,rg_note,hr_note)
            else
            # if the note is new, create it in Highrise and map it
              hr_note = Highrise::Note.new
              self.rg_note_to_hr_note(contact_map,rg_note,hr_note)
            end
            
            # if the Highrise note is saved properly and it didn't exist before, create a new note map
            new_hr_note = hr_note.new?
            unless new_hr_note
              hr_note = self.remove_subject_name(hr_note)
            end
            if hr_note.save! && new_hr_note
              new_nm = NoteMap.new(:contact_map_id => contact_map.id, :author_user_map_id => author_user_map.id, :rg_note_id => rg_note.id, :hr_note_id => hr_note.id)
              new_nm.save!
            end

            ApiOperations::Common.log(:debug,nil,"Finished applying update from Ringio to Highrise of the note with Ringio id = " + rg_note.id.to_s)            
          end
        end        
      end


      def self.delete_rg_to_hr(author_user_map, rg_deleted_notes_ids)
        rg_deleted_notes_ids.each do |dn_id|
          ApiOperations::Common.log(:debug,nil,"Started applying deletion from Ringio to Highrise of the note with Ringio id = " + dn_id.to_s)

          # if the note was already mapped to Highrise for this author user map, delete it there
          if (nm = NoteMap.find_by_author_user_map_id_and_rg_note_id(author_user_map.id,dn_id))
            hr_note = nm.hr_resource_note
            hr_note.destroy
            nm.destroy
          end
          # otherwise, don't do anything, because that Ringio contact has not been created yet in Highrise

          ApiOperations::Common.log(:debug,nil,"Finished applying deletion from Ringio to Highrise of the note with Ringio id = " + dn_id.to_s)
        end
      end


      def self.remove_subject_name(hr_note)
        # TODO: remove this method or find a better way to do it (answer pending in the 37signals mailing list) 
        Highrise::Note.new(
          :author_id => hr_note.author_id,
          :body => hr_note.body,
          :collection_id => hr_note.collection_id,
          :collection_type => hr_note.collection_type,
          :created_at => hr_note.created_at,
          :group_id => hr_note.group_id,
          :id => hr_note.id,
          :owner_id => hr_note.owner_id,
          :subject_id => hr_note.subject_id,
          :subject_type => hr_note.subject_type,
          :updated_at => hr_note.updated_at,
          :visible_to => hr_note.visible_to
        )
      end


      def self.rg_note_to_hr_note(contact_map, rg_note,hr_note)
        # Highrise assumes that the author of the note is the currently authenticated user, we don't have to specify the author_id
        hr_note.subject_id = contact_map.hr_party_id
        hr_note.subject_type = 'Party'
        # it is not necessary to specify if it is a Person or a Company (they can't have id collision),
        # and Highrise does not offer a way to specify it 
        hr_note.body = rg_note.body
      end

  end

end