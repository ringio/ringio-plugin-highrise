module ApiOperations

  module Notes

    def self.synchronize_contact(contact_map)

      # get the feed of changed notes both in Ringio and Highrise
      rg_notes_feed = contact_map.rg_notes_feed
      rg_updated_notes_ids = rg_notes_feed.updated
      rg_deleted_notes_ids = rg_notes_feed.deleted

      hr_parties_feed = user_map.hr_parties_feed
      hr_updated_people = hr_parties_feed[0]
      hr_updated_companies = hr_parties_feed[1]
      hr_party_deletions = hr_parties_feed[2]

      # give priority to Highrise: discard changes in Ringio to contacts that have been changed in Highrise
      self.purge_contacts(hr_updated_people,hr_updated_companies,hr_party_deletions,rg_updated_contacts_ids,rg_deleted_contacts_ids)

      self.apply_changes_rg_to_hr(user_map,rg_updated_contacts_ids,rg_deleted_contacts_ids)

      self.apply_changes_hr_to_rg(user_map,hr_updated_people,hr_updated_companies,hr_party_deletions)

      user_map.rg_last_timestamp = rg_contacts_feed.timestamp

    end

  end

end