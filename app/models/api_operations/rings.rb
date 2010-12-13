module ApiOperations

  module Rings

    def self.synchronize_contact(contact_map)
      
      # get the feed of changed rings both in Ringio and Highrise
      rg_rings_feed = contact_map.rg_rings_feed
      rg_updated_rings_ids = rg_rings_feed.updated
      rg_deleted_rings_ids = rg_rings_feed.deleted

      # reject the rings from users different than the current one
      hr_notes = contact_map.hr_notes_feed.reject{|n| n.author_id.to_i != contact_map.user_map.hr_user_id}

      # give priority to Highrise: apply changes first to Ringio
      new_hr_notes_ids = []
      self.apply_changes_rg_to_hr(contact_map,rg_updated_rings_ids,rg_deleted_rings_ids,new_hr_notes_ids)
      self.apply_changes_hr_to_rg(contact_map,hr_notes,new_hr_notes_ids)

      # update timestamps: we must set the timestamp AFTER the changes we made in the synchronization, or
      # we would update those changes again and again in every synchronization (and, to keep it simple, we ignore
      # the changes that other agents may have caused for this user just when we were synchronizing)
      # TODO: ignore only our changes but not the changes made by other agents
      contact_map.rg_last_timestamp = contact_map.rg_rings_feed.timestamp
      contact_map.save
    end


    private

      def self.apply_changes_hr_to_rg(contact_map,hr_notes,new_hr_notes_ids)
        hr_notes.each do |hr_note|
          rg_ring = self.prepare_rg_ring(contact_map,hr_note)
          self.hr_note_to_rg_ring(contact_map,hr_note,rg_ring)
  
          # if the Ringio ring is saved properly and it didn't exist before, create a new ring map
          new_rg_ring = rg_ring.new?
          if rg_ring.save! && new_rg_ring
            new_rm = RingMap.new(:contact_map_id => contact_map.id, :rg_ring_id => rg_ring.id, :hr_note_id => hr_note.id)
            new_rm.save!
          end
        end

        # check to destroy all currently mapped Ringio rings that don't exist anymore in Highrise
        # (remember that Highrise does not offer a feed for note deletions)
        contact_map.ring_maps.each do |rm|
          # skip Highrise notes that have just been created
          if new_hr_notes_ids.include?(rm.hr_note_id)
            next
          end
          
          # check only for rings from the current user
          rg_ring = rm.rg_resource_ring
          if rg_ring.author_id.to_i == contact_map.user_map.rg_user_id
            unless hr_notes.index{|n| n.id == rm.hr_note_id}
              rg_ring.destroy
              rm.destroy
            end
          end
        end
      end


      def self.prepare_rg_ring(contact_map,hr_note)
        # if the ring was already mapped to Ringio, we must update it there
        if (rm = RingMap.find_by_hr_note_id(hr_note.id))
          rg_ring = rm.rg_resource_ring
        else
        # if the ring is new, we must create it in Ringio
          # in Ringio (unlike in Highrise) we don't have one token per user, so we have to specify the author of the new ring
          rg_ring = RingioAPI::Ring.new(:author_id => contact_map.user_map.rg_user_id)
        end
        rg_ring
      end


      def self.hr_note_to_rg_ring(contact_map,hr_note,rg_ring)
        rg_ring.contact_id = contact_map.rg_contact_id
        rg_ring.body =  hr_note.body  
      end


      def self.apply_changes_rg_to_hr(contact_map,rg_updated_rings_ids,rg_deleted_rings_ids,new_hr_notes_ids)

        rg_updated_rings_ids.each do |rg_ring_id|
          # if the ring was already mapped to Highrise, update it there
          if (rm = RingMap.find_by_rg_ring_id(rg_ring_id))
            rg_ring = rm.rg_resource_ring
            # skip rings from users different than the current one or that were created in Highrise
            if (rg_ring.author_id.to_i != contact_map.user_map.rg_user_id) || (rg_ring.body[0,14] == 'See Highrise: ')
              next
            end
            hr_note = rm.hr_resource_note
            self.rg_ring_to_hr_note(contact_map,rg_ring,hr_note)
          else
          # if the ring is new, create it in Highrise and map it
            rg_ring = RingioAPI::Ring.find(rg_ring_id)
            # skip rings from users different than the current one
            if rg_ring.author_id.to_i != contact_map.user_map.rg_user_id
              next
            end
            hr_note = Highrise::Note.new
            self.rg_ring_to_hr_note(contact_map,rg_ring,hr_note)
          end
          
          # if the Highrise note is saved properly and it didn't exist before, create a new ring map
          new_hr_note = hr_note.new?
          unless new_hr_note
            hr_note = self.remove_subject_name(hr_note)
          end
          if hr_note.save! && new_hr_note
            new_rm = RingMap.new(:contact_map_id => contact_map.id, :rg_ring_id => rg_ring_id, :hr_note_id => hr_note.id)
            new_rm.save!
            new_hr_notes_ids << hr_note.id
          end
        end
        
        rg_deleted_rings_ids.each do |dn_id|
          # if the ring was already mapped to Highrise, delete it there
          if (rm = RingMap.find_by_rg_ring_id(dn_id))
            hr_note = rm.hr_resource_note
            hr_note.destroy
            rm.destroy
          end
          # otherwise, don't do anything, because that Ringio contact has not been created yet in Highrise
        end
      end


      def self.remove_subject_name(hr_note)
        # TODO: remove this method or find a better way to do it (answer pending in the 37signals mailing list) 
        Highrise::Ring.new(
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


      def self.rg_ring_to_hr_note(contact_map,rg_ring,hr_note)
        hr_note.subject_id = contact_map.hr_party_id
        hr_note.subject_type = 'Party'
        # it is not necessary to specify if it is a Person or a Company (they can't have id collision),
        # and Highrise does not offer a way to specify it 
        hr_note.body = rg_ring.body
      end

  end

end