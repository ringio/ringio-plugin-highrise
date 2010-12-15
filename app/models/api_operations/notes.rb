module ApiOperations

  module Notes

    def self.synchronize_account(account)
      
      # get the feed of changed notes per contact of this Ringio account from Ringio
      account_rg_feed = account.rg_notes_feed
debugger
      contact_rg_feeds = self.fetch_contact_rg_feeds(account_rg_feed,account)
      rg_deleted_note_ids = account_rg_feed.deleted

      # synchronize each contact whose notes have changed
      contact_rg_feeds.each do |rg_feed|
        ApiOperations::Common.set_hr_base rg_feed[0]
        self.synchronize_contact(rg_feed,rg_deleted_note_ids)
        ApiOperations::Common.empty_hr_base
      end

      # update timestamps: we must set the timestamp AFTER the changes we made in the synchronization, or
      # we would update those changes again and again in every synchronization (and, to keep it simple, we ignore
      # the changes that other agents may have caused for this user just when we were synchronizing)
      # TODO: ignore only our changes but not the changes made by other agents
      account.rg_notes_last_timestamp = account.rg_notes_feed.timestamp
      account.hr_notes_last_synchronized_at = ApiOperations::Common.hr_current_timestamp(account.user_maps.first)
      account.save

    end


    private


      # returns an array with each element containing information for each contact map:
      # [0] => user map of this contact map
      # [1] => updated Ringio notes for this contact map
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


      def self.synchronize_contact(rg_feed, rg_deleted_note_ids)

        # reject the notes from users different than the current one
        hr_notes = contact_map.hr_notes_feed.reject{|n| n.author_id.to_i != contact_map.user_map.hr_user_id}
  
        # give priority to Highrise: apply changes first to Ringio
        new_hr_notes_ids = []
        self.apply_changes_rg_to_hr(contact_map,rg_updated_notes_ids,rg_deleted_notes_ids,new_hr_notes_ids)
        self.apply_changes_hr_to_rg(contact_map,hr_notes,new_hr_notes_ids)        

      end


      def self.apply_changes_hr_to_rg(contact_map, hr_notes, new_hr_notes_ids)
        hr_notes.each do |hr_note|
          rg_note = self.prepare_rg_note(contact_map,hr_note)
          self.hr_note_to_rg_note(contact_map,hr_note,rg_note)
  
          # if the Ringio note is saved properly and it didn't exist before, create a new note map
          new_rg_note = rg_note.new?
          if rg_note.save! && new_rg_note
            new_nm = NoteMap.new(:contact_map_id => contact_map.id, :rg_note_id => rg_note.id, :hr_note_id => hr_note.id)
            new_nm.save!
          end
        end

        # check to destroy all currently mapped Ringio notes that don't exist anymore in Highrise
        # (remember that Highrise does not offer a feed for note deletions)
        contact_map.note_maps.each do |nm|
          # skip Highrise notes that have just been created
          if new_hr_notes_ids.include?(nm.hr_note_id)
            next
          end
          
          # check only for notes from the current user
          rg_note = nm.rg_resource_note
          if rg_note.author_id.to_i == contact_map.user_map.rg_user_id
            unless hr_notes.index{|n| n.id == nm.hr_note_id}
              rg_note.destroy
              nm.destroy
            end
          end
        end
      end


      def self.prepare_rg_note(contact_map, hr_note)
        # if the note was already mapped to Ringio, we must update it there
        if (nm = NoteMap.find_by_hr_note_id(hr_note.id))
          rg_note = nm.rg_resource_note
        else
        # if the note is new, we must create it in Ringio
          # in Ringio (unlike in Highrise) we don't have one token per user, so we have to specify the author of the new note
          rg_note = RingioAPI::Note.new(:author_id => contact_map.user_map.rg_user_id)
        end
        rg_note
      end


      def self.hr_note_to_rg_note(contact_map, hr_note, rg_note)
        rg_note.contact_id = contact_map.rg_contact_id
        rg_note.body =  hr_note.body  
      end


      def self.apply_changes_rg_to_hr(contact_map, rg_updated_notes_ids, rg_deleted_notes_ids, new_hr_notes_ids)

        rg_updated_notes_ids.each do |rg_note_id|
          # if the note was already mapped to Highrise, update it there
          if (nm = NoteMap.find_by_rg_note_id(rg_note_id))
            rg_note = nm.rg_resource_note
            # skip notes from users different than the current one or that were created in Highrise
            if (rg_note.author_id.to_i != contact_map.user_map.rg_user_id) || (rg_note.body[0,14] == 'See Highrise: ')
              next
            end
            hr_note = nm.hr_resource_note
            self.rg_note_to_hr_note(contact_map,rg_note,hr_note)
          else
          # if the note is new, create it in Highrise and map it
            rg_note = RingioAPI::Note.find(rg_note_id)
            # skip notes from users different than the current one
            if rg_note.author_id.to_i != contact_map.user_map.rg_user_id
              next
            end
            hr_note = Highrise::Note.new
            self.rg_note_to_hr_note(contact_map,rg_note,hr_note)
          end
          
          # if the Highrise note is saved properly and it didn't exist before, create a new note map
          new_hr_note = hr_note.new?
          unless new_hr_note
            hr_note = self.remove_subject_name(hr_note)
          end
          if hr_note.save! && new_hr_note
            new_nm = NoteMap.new(:contact_map_id => contact_map.id, :rg_note_id => rg_note_id, :hr_note_id => hr_note.id)
            new_nm.save!
            new_hr_notes_ids << hr_note.id
          end
        end
        
        rg_deleted_notes_ids.each do |dn_id|
          # if the note was already mapped to Highrise, delete it there
          if (nm = NoteMap.find_by_rg_note_id(dn_id))
            hr_note = nm.hr_resource_note
            hr_note.destroy
            nm.destroy
          end
          # otherwise, don't do anything, because that Ringio contact has not been created yet in Highrise
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
        hr_note.subject_id = contact_map.hr_party_id
        hr_note.subject_type = 'Party'
        # it is not necessary to specify if it is a Person or a Company (they can't have id collision),
        # and Highrise does not offer a way to specify it 
        hr_note.body = rg_note.body
      end

  end

end