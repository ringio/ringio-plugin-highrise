class ContactMap < ActiveRecord::Base
  
  belongs_to :user_map
  
  validates_presence_of :user_map_id, :rg_contact_id, :hr_party_id, :hr_party_type 
  validates_uniqueness_of :rg_contact_id
  validates_uniqueness_of :hr_party_id, :scope => :hr_party_type
  validates_uniqueness_of :hr_party_type, :scope => :hr_party_id
  
  def hr_resource_party
    case self.hr_party_type 
      when 'Person'
        Highrise::Person.find self.hr_party_id
      when 'Company'
        Highrise::Company.find self.hr_party_id
      else
        raise 'Incomplete contact map'
    end
  end
  
  def rg_resource_contact
    RingioAPI::Contact.find self.rg_contact_id
  end
  
  def rg_notes_feed
    # TODO: give support to note visibility (same as the contact)
    feed = RingioAPI::Feed.find(
      :one,
      :from => RingioAPI::Feed.prefix + "feeds/contacts/" + self.rg_contact_id.to_s + "/notes",
      :params => { :since => self.rg_last_timestamp }
    )
    self.rg_last_timestamp = feed.timestamp
    feed
  end
  
  def hr_notes_feed
debugger
    # get only the Highrise notes that were created by this user and
    # filter to keep those that were created_at or updated_at after the last synchronization datetime
    
    # to filter by date, we have to request recordings and then filter the notes 
    hr_updated_recordings = Highrise::Recording.find_all_across_pages_since(self.hr_last_synchronized_at).reject{ |r|
      (r.type != 'Note') ||
      (! self.user_map.account.has_hr_user(r.author_id)) ||
      ()
    }

    # TODO: give support to visibility (same as the contact)

    # get deletions of person and companies, mind that author_id is not provided
    hr_party_deletions = Highrise::Party.deletions_since(self.hr_last_synchronized_at)

    update_hr_last_synchronized_at
    
    [hr_updated_people,hr_updated_companies,hr_party_deletions]
  end
  
end
