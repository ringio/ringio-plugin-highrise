module ApiOperations

  module Rings

    def self.synchronize_account(account)
      ApiOperations::Common.log(:debug,nil,"Started the synchronization of the rings of the account with id = " + account.id.to_s)

      begin
        # get the feed of changed rings per contact of this Ringio account from Ringio,
        # we will not check for deleted rings, because they cannot be deleted
        ApiOperations::Common.log(:debug,nil,"Getting the changed rings of the account with id = " + account.id.to_s)
        account_rg_feed = account.rg_rings_feed
        contact_rg_feeds = self.fetch_contact_rg_feeds(account_rg_feed,account)
      rescue Exception => e
        ApiOperations::Common.log(:error,e,"\nProblem fetching the changed rings of the account with id = " + account.id.to_s)
      end

      self.synchronize_contacts contact_rg_feeds
      
      self.update_timestamps account

      ApiOperations::Common.log(:debug,nil,"Finished the synchronization of the rings of the account with id = " + account.id.to_s)
    end


    private


      def self.update_timestamps(account)
        begin
          # update timestamps: we must set the timestamp AFTER the changes we made in the synchronization, or
          # we would update those changes again and again in every synchronization (and, to keep it simple, we ignore
          # the changes that other agents may have caused for this account just when we were synchronizing)
          # TODO: ignore only our changes but not the changes made by other agents
          account.rg_rings_last_timestamp = account.rg_rings_feed.timestamp
          account.hr_ring_notes_last_synchronized_at = ApiOperations::Common.hr_current_timestamp(account.user_maps.first)
          account.save
        rescue Exception => e
          ApiOperations::Common.log(:error,e,"\nProblem updating the ring synchronization timestamps of the account with id = " + account.id.to_s)
        end      
      end

      
      def self.synchronize_contacts(contact_rg_feeds)
        # synchronize each contact whose rings have changed
        contact_rg_feeds.each do |contact_feed|
          begin
            ApiOperations::Common.set_hr_base(contact_feed[0].user_map)
            self.synchronize_contact(contact_feed)
            ApiOperations::Common.empty_hr_base
          rescue Exception => e
            ApiOperations::Common.log(:error,e,"\nProblem synchronizing the rings created for the contact map with id = " + contact_feed[0].id.to_s)
          end
        end      
      end
      
      
      # returns an array with each element containing information for each contact map:
      # [0] => contact map
      # [1] => updated Ringio rings for this contact map
      # we will choose the author of the ring event note in Highrise as the owner of the contact 
      def self.fetch_contact_rg_feeds(account_rg_feed, account)

        account_rg_feed.updated.inject([]) do |contact_feeds,rg_ring_id|
          rg_ring = RingioAPI::Ring.find rg_ring_id
          
          if rg_ring.from_type == 'contact'
            process_rg_ring(rg_ring.from_id,contact_feeds,rg_ring,account)
          elsif rg_ring.to_type == 'contact'
            process_rg_ring(rg_ring.to_id,contact_feeds,rg_ring,account)
          end

          contact_feeds
        end
        
      end


      def self.process_rg_ring(rg_contact_id, contact_feeds, rg_ring, account)
        # synchronize only notes of contacts already mapped for this account
        if (cm = ContactMap.find_by_rg_contact_id(rg_contact_id)) && (cm.user_map.account == account)
          if (cf_index = contact_feeds.index{|cf| cf[0] == cm})
            contact_feeds[cf_index][1] << rg_ring
          else
            contact_feeds << [cm,[rg_ring]]
          end
        end
      end


      def self.synchronize_contact(contact_rg_feed)

        # we will only check for updated rings in Ringio, as they should not be changed in Highrise
        contact_map = contact_rg_feed[0]
        rg_updated_rings = contact_rg_feed[1]
        
        # we will only check for updated rings, as they cannot be deleted
        rg_updated_rings.each do |rg_ring|
          ApiOperations::Common.log(:debug,nil,"Started applying update from Ringio to Highrise of the ring with Ringio id = " + rg_ring.id.to_s)
          
          # if the ring was already mapped to Highrise, update it there
          if (rm = RingMap.find_by_rg_ring_id(rg_ring.id))
            hr_ring_note = rm.hr_resource_ring_note
            self.rg_ring_to_hr_ring_note(contact_map,rg_ring,hr_ring_note)
          else
          # if the note is new, create it in Highrise and map it
            hr_ring_note = Highrise::Note.new
            self.rg_ring_to_hr_ring_note(contact_map,rg_ring,hr_ring_note)
          end
          
          # if the Highrise note is saved properly and it didn't exist before, create a new ring map
          new_hr_ring_note = hr_ring_note.new?
          unless new_hr_ring_note
            hr_ring_note = self.remove_subject_name(hr_ring_note)
          end
          if hr_ring_note.save! && new_hr_ring_note
            new_rm = RingMap.new(:contact_map_id => contact_map.id, :rg_ring_id => rg_ring.id, :hr_ring_note_id => hr_ring_note.id)
            new_rm.save!
          end
          
          ApiOperations::Common.log(:debug,nil,"Finished applying update from Ringio to Highrise of the ring with Ringio id = " + rg_ring.id.to_s)
        end
      end


      def self.remove_subject_name(hr_ring_note)
        # TODO: remove this method or find a better way to do it (answer pending in the 37signals mailing list) 
        Highrise::Note.new(
          :author_id => hr_ring_note.author_id,
          :body => hr_ring_note.body,
          :collection_id => hr_ring_note.collection_id,
          :collection_type => hr_ring_note.collection_type,
          :created_at => hr_ring_note.created_at,
          :group_id => hr_ring_note.group_id,
          :id => hr_ring_note.id,
          :owner_id => hr_ring_note.owner_id,
          :subject_id => hr_ring_note.subject_id,
          :subject_type => hr_ring_note.subject_type,
          :updated_at => hr_ring_note.updated_at,
          :visible_to => hr_ring_note.visible_to
        )
      end


      def self.rg_ring_to_hr_ring_note(contact_map, rg_ring, hr_ring_note)
        # Highrise assumes that the author of the ring note is the currently authenticated user, we don't have to specify the author_id
        hr_ring_note.subject_id = contact_map.hr_party_id
        hr_ring_note.subject_type = 'Party'
        # it is not necessary to specify if it is a Person or a Company (they can't have id collision),
        # and Highrise does not offer a way to specify it
          
        from = case rg_ring.from_type
          when 'user' then RingioAPI::User.find rg_ring.from_id
          when 'contact' then RingioAPI::Contact.find rg_ring.from_id
          else
            raise 'Unknown Ring From type'
        end
        
        to = case rg_ring.to_type
          when 'user' then RingioAPI::User.find rg_ring.to_id
          when 'contact' then RingioAPI::Contact.find rg_ring.to_id
          else
            raise 'Unknown Ring To type'
        end

        hr_ring_note.body = "RING - DO NOT CHANGE OR DELETE THIS NOTE\n" +
                            "From: " + rg_ring.from_type + " " + from.name + " " + rg_ring.callerid + "\n" +
                            "To: " + rg_ring.to_type + " " + to.name + " " + rg_ring.called_number + "\n" +
                            "Start Time: " + rg_ring.start_time + "\n" +
                            "Duration:  " + rg_ring.duration.to_s + "\n" +
                            "Outcome:  " + rg_ring.outcome + "\n" +
                            "Voicemail:  " + (rg_ring.attributes['voicemail'].present? ? rg_ring.voicemail : '') + "\n" +
                            "Kind:  " + rg_ring.kind + "\n" +
                            "Department:  " + (rg_ring.attributes['department'].present? ? rg_ring.department : '') + "\n"                            
      end

  end

end