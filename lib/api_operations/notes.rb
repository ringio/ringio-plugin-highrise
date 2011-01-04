module ApiOperations

  module Notes

    def self.synchronize_account(account, new_user_maps)
      ApiOperations::Common.log(:debug,nil,"Started the synchronization of the notes of the account with id = " + account.id.to_s)

      # run a synchronization just for each new user map
      new_user_maps.each do |um|
        self.synchronize_account_process(account,um)
      end
      
      # run a normal complete synchronization
      self.synchronize_account_process(account,nil) unless account.not_synchronized_yet

      self.update_timestamps account
      
      ApiOperations::Common.log(:debug,nil,"Finished the synchronization of the notes of the account with id = " + account.id.to_s)
    end


    private

      def self.synchronize_account_process(account, user_map)
        # if there is a new user map
        if user_map
          ApiOperations::Common.log(:debug,nil,"Started note synchronization for the new user map with id = " + user_map.id.to_s + " of the account with id = " + account.id.to_s)

          begin
            # get the feed of changed notes per contact of this new user map
            user_feed = self.fetch_individual_user_feed user_map
            # as it is the first synchronization for this user map, we are not interested in deleted notes
            rg_deleted_notes_ids = []
          rescue Exception => e
            ApiOperations::Common.log(:error,e,"\nProblem fetching the changed notes for the new user map with id = " + user_map.id.to_s + " of the account with id = " + account.id.to_s)
          end
          
          begin
            self.synchronize_user user_feed
          rescue Exception => e
            ApiOperations::Common.log(:error,e,"\nProblem synchronizing the notes of the new user map with id = " + user_map.id.to_s)
          end

          ApiOperations::Common.log(:debug,nil,"Finished note synchronization for the new user map with id = " + user_map.id.to_s + " of the account with id = " + account.id.to_s)
        else
          begin
            # get the feed of changed notes per contact of this Ringio account
            ApiOperations::Common.log(:debug,nil,"Getting the changed notes of the account with id = " + account.id.to_s)
            account_rg_feed = account.rg_notes_feed
            user_feeds = self.fetch_user_feeds(account_rg_feed,account)
            rg_deleted_notes_ids = account_rg_feed.deleted
          rescue Exception => e
            ApiOperations::Common.log(:error,e,"\nProblem fetching the changed notes of the account with id = " + account.id.to_s)
          end
    
          self.synchronize_contacts(account,user_feeds,rg_deleted_notes_ids)
        end
      end


      def self.synchronize_user(user_feed)
        begin
          user_map = user_feed[0]
          if user_map
            # we have to check all contacts in this account, not only the ones owned by this user,
            # because users can create notes for contacts that are not owned by them
            user_map.account.user_maps.each do |um|
              um.contact_maps.each do |cm|
                begin
                  contact_feed = (c_f_index = user_feed[1].index{|contact_feed| contact_feed[0] == cm})? user_feed[1][c_f_index] : [cm,[],[]]
                  contact_rg_feed = [contact_feed[0],contact_feed[1]]
                  hr_updated_note_recordings = contact_feed[2]
                  self.synchronize_contact(true,user_map,cm,contact_rg_feed,[],hr_updated_note_recordings)
                rescue Exception => e
                  ApiOperations::Common.log(:error,e,"\nProblem synchronizing the notes created by the new user map with id = " + user_map.id.to_s + " for the contact map with id = " + cm.id.to_s)
                end
              end
            end
          end
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
    
    
      def self.synchronize_contacts(account, user_feeds, rg_deleted_notes_ids)
        begin
          # synchronize the notes created by every user of this account
          user_feeds.each do |uf|
            um = uf[0]
            next if um.account != account
            begin
              # we have to check all contacts in this account, not only the ones owned by this user,
              # because users can create notes for contacts that are not owned by them
              um.account.user_maps.each do |aux_um|
                aux_um.contact_maps.each do |cm|
                  begin
                    user_feed = (u_f_index = user_feeds.index{|uf| uf[0] == um})? user_feeds[u_f_index] : nil
                    contact_feed = user_feed.present? ? ((c_f_index = user_feed[1].index{|contact_feed| contact_feed[0] == cm})? user_feed[1][c_f_index] : [cm,[],[]]) : [cm,[],[]]
                    contact_rg_feed = [contact_feed[0],contact_feed[1]]
                    hr_updated_note_recordings = contact_feed[2]
                    self.synchronize_contact(false,um,cm,contact_rg_feed,rg_deleted_notes_ids,hr_updated_note_recordings)
                  rescue Exception => e
                    ApiOperations::Common.log(:error,e,"\nProblem synchronizing the notes created by the user map with id = " + um.id.to_s + " for the contact map with id = " + cm.id.to_s)
                  end
                end
              end
            rescue Exception => e
              ApiOperations::Common.log(:error,e,"\nProblem synchronizing the notes created by the user map with id = " + um.id.to_s)
            end
          end
        rescue Exception => e
          ApiOperations::Common.log(:error,e,"\nProblem synchronizing the notes")
        end
      end


      # behaves like self.fetch_user_rg_feeds but just for the element of the array for this user map
      def self.fetch_individual_user_feed(user_map)
        # get updated notes from Ringio
        user_feed = user_map.account.all_rg_notes_feed.updated.inject([user_map,[]]) do |user_feed,rg_note_id|
          rg_note = RingioAPI::Note.find rg_note_id

          # synchronize only notes created by this user
          if user_map.rg_user_id.to_s == rg_note.author_id
            # synchronize only notes created for contacts already mapped for this account
            if (cm = ContactMap.find_by_rg_contact_id(rg_note.contact_id)) && (cm.user_map.account == user_map.account)
              if (cf_index = user_feed[1].index{|cf| cf[0] == cm})
                user_feed[1][cf_index][1] << rg_note
              else
                user_feed[1] << [cm,[rg_note],[]]
              end
            end
          end

          user_feed
        end

        # get updated notes from Highrise
        ApiOperations::Common.set_hr_base user_map
        user_feed = user_map.hr_updated_note_recordings(true).inject(user_feed) do |user_feed,hr_note_recording|
          # synchronize only notes created for contacts already mapped for this account
          # it is not necessary to specify if it is a Person or a Company (they can't have id collision),
          # and Highrise does not offer the distinction in the recording 
          if (cm = ContactMap.find_by_hr_party_id(hr_note_recording.subject_id)) && (cm.user_map.account == user_map.account)
            if (cf_index = user_feed[1].index{|cf| cf[0] == cm})
              user_feed[1][cf_index][2] << hr_note_recording
            else
              user_feed[1] << [cm,[],[hr_note_recording]]
            end
          end
          
          user_feed
        end
        ApiOperations::Common.empty_hr_base
      end

      
      # returns an array with each element containing information for each author user map:
      # [0] => author user map
      # [1][i][0] => contact map i
      # [1][i][1] => updated Ringio notes for contact map i and author user map
      # [1][i][2] => updated Highrise notes for contact map i and author user map
      def self.fetch_user_feeds(account_rg_feed, account)
        # get updated notes from Ringio
        user_feeds = account_rg_feed.updated.inject([]) do |user_feeds,rg_note_id|
          rg_note = RingioAPI::Note.find rg_note_id

          # synchronize only notes created by users already mapped for this account
          if (um = UserMap.find_by_account_id_and_rg_user_id(account.id,rg_note.author_id))
            # synchronize only notes created for contacts already mapped for this account
            if (cm = ContactMap.find_by_rg_contact_id(rg_note.contact_id)) && (cm.user_map.account == account)
              if (uf_index = user_feeds.index{|uf| uf[0] == um})
                if (cf_index = user_feeds[uf_index][1].index{|cf| cf[0] == cm})
                  user_feeds[uf_index][1][cf_index][1] << rg_note
                else
                  user_feeds[uf_index][1] << [cm,[rg_note],[]]
                end
              else
                user_feeds << [ um , [[cm,[rg_note],[]]] ]
              end
            end
          end

          user_feeds
        end

        # get updated notes from Highrise
        account.user_maps.each do |um|
          ApiOperations::Common.set_hr_base um
          user_feeds = um.hr_updated_note_recordings(false).inject(user_feeds) do |user_feeds,hr_note_recording|
            # synchronize only notes created for contacts already mapped for this account
            # it is not necessary to specify if it is a Person or a Company (they can't have id collision),
            # and Highrise does not offer the distinction in the recording
            if (cm = ContactMap.find_by_hr_party_id(hr_note_recording.subject_id)) && (cm.user_map.account == account)
              if (uf_index = user_feeds.index{|uf| uf[0] == um})
                if (cf_index = user_feeds[uf_index][1].index{|cf| cf[0] == cm})
                  user_feeds[uf_index][1][cf_index][2] << hr_note_recording
                else
                  user_feeds[uf_index][1] << [cm,[],[hr_note_recording]]
                end
              else
                user_feeds << [ um , [[cm,[],[hr_note_recording]]] ]
              end
            end
            
            user_feeds
          end
          ApiOperations::Common.empty_hr_base
        end
        
        user_feeds
      end


      def self.synchronize_contact(is_new_user, author_user_map, contact_map, contact_rg_feed, rg_deleted_notes_ids, hr_updated_note_recordings)
        ApiOperations::Common.log(:debug,nil,"Started applying note changes for the contact map with id = " + contact_map.id.to_s + " by the author user map with id = " + author_user_map.id.to_s)
        ApiOperations::Common.set_hr_base author_user_map

        # TODO: get true feeds of deleted notes (currently Highrise does not offer it)
        hr_notes = contact_map.hr_notes

        # get the deleted notes (those that don't appear anymore in the current set)
        hr_deleted_notes_ids = is_new_user ? [] : contact_map.note_maps.reject{|nm| hr_notes.index{|hr_n| hr_n.id == nm.hr_note_id}}.map{|nm| nm.hr_note_id}

        # empty the variable for the current set to make sure it is not used, as the feed is more efficient
        hr_notes = nil

        if contact_rg_feed.present? || rg_deleted_notes_ids.present? || hr_updated_note_recordings.present? || hr_deleted_notes_ids.present?
          # give priority to Highrise: discard changes in Ringio to notes that have been changed in Highrise
          self.purge_duplicated_changes(hr_updated_note_recordings,hr_deleted_notes_ids,contact_rg_feed,rg_deleted_notes_ids)

          # apply changes from Ringio to Highrise
          self.update_rg_to_hr(author_user_map,contact_map,contact_rg_feed)
          self.delete_rg_to_hr(author_user_map,rg_deleted_notes_ids) unless is_new_user

          # apply changes from Highrise to Ringio
          self.update_hr_to_rg(author_user_map,contact_map,hr_updated_note_recordings)
          self.delete_hr_to_rg(author_user_map,hr_deleted_notes_ids) unless is_new_user
        end

        ApiOperations::Common.empty_hr_base
        ApiOperations::Common.log(:debug,nil,"Finished applying note changes for the contact map with id = " + contact_map.id.to_s + " by the author user map with id = " + author_user_map.id.to_s)
      end


      def self.purge_duplicated_changes(hr_updated_note_recordings, hr_deleted_notes_ids, contact_rg_feed, rg_deleted_notes_ids)
        begin
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
        rescue Exception => e
          ApiOperations::Common.log(:error,e,"\nProblem purging the duplicated changes of the notes")
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
          begin
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
          rescue Exception => e
            ApiOperations::Common.log(:error,e,"Problem applying update from Highrise to Ringio of the note with Highrise id = " + hr_note.id.to_s)
          end
        end
      end


      def self.delete_hr_to_rg(author_user_map, hr_deleted_notes_ids)
        hr_deleted_notes_ids.each do |n_id|
          begin
            ApiOperations::Common.log(:debug,nil,"Started applying deletion from Highrise to Ringio of the note with Highrise id = " + n_id.to_s)
            
            # if the note was already mapped to Ringio for this author user map, delete it there
            if (nm = NoteMap.find_by_author_user_map_id_and_hr_note_id(author_user_map.id,n_id))
              nm.rg_resource_note.destroy
              nm.destroy
            end
            # otherwise, don't do anything, because that Highrise party has not been created yet in Ringio
            
            ApiOperations::Common.log(:debug,nil,"Finished applying deletion from Highrise to Ringio of the note with Highrise id = " + n_id.to_s)
          rescue Exception => e
            ApiOperations::Common.log(:error,e,"Problem applying deletion from Highrise to Ringio of the note with Highrise id = " + n_id.to_s)
          end
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
        contact_rg_feed[1].each do |rg_note|
          begin
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
          rescue Exception => e
            ApiOperations::Common.log(:error,e,"Problem applying update from Ringio to Highrise of the note with Ringio id = " + rg_note.id.to_s)
          end
        end
      end


      def self.delete_rg_to_hr(author_user_map, rg_deleted_notes_ids)
        rg_deleted_notes_ids.each do |dn_id|
          begin
            ApiOperations::Common.log(:debug,nil,"Started applying deletion from Ringio to Highrise of the note with Ringio id = " + dn_id.to_s)
  
            # if the note was already mapped to Highrise for this author user map, delete it there
            if (nm = NoteMap.find_by_author_user_map_id_and_rg_note_id(author_user_map.id,dn_id))
              hr_note = nm.hr_resource_note
              hr_note.destroy
              nm.destroy
            end
            # otherwise, don't do anything, because that Ringio contact has not been created yet in Highrise
  
            ApiOperations::Common.log(:debug,nil,"Finished applying deletion from Ringio to Highrise of the note with Ringio id = " + dn_id.to_s)
          rescue Exception => e
            ApiOperations::Common.log(:error,e,"Problem applying deletion from Ringio to Highrise of the note with Ringio id = " + dn_id.to_s)
          end
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