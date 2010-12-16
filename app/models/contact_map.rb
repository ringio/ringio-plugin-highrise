class ContactMap < ActiveRecord::Base
  
  belongs_to :user_map
  has_many :note_maps, :dependent => :destroy
  has_many :ring_maps, :dependent => :destroy
  
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
        raise 'Unknown party type'
    end
  end
  
  def rg_resource_contact
    RingioAPI::Contact.find self.rg_contact_id
  end
  
  def hr_notes
    # get only the Highrise notes that belong this contact
    case self.hr_party_type
      when 'Person' then Highrise::Note.find_all_across_pages(:from => '/people/' + self.hr_party_id + '/notes.xml')
      when 'Company' then Highrise::Note.find_all_across_pages(:from => '/companies/' + self.hr_party_id + '/notes.xml')
      else raise 'Unknown party type'
    end
    # TODO: give support to visibility
  end

  def hr_updated_note_recordings
    # get only the Highrise recordings for notes for the current contact and user and
    # filter to keep those that were created_at or updated at after the last synchronization datetime
    Highrise::Recording.find_all_across_pages_since(self.account.hr_notes_last_synchronized_at).reject do |r|
      (r.type != 'Note') || (r.subject_type != 'Party') || (r.subject_id.to_i != self.hr_party_id) || (r.author_id.to_i != self.user_map.hr_user_id)
    end
  end
  
  def hr_rings_feed
    # get only the Highrise notes that were created for this contact
    case self.hr_party_type
      when 'Person' then (Highrise::Person.find(self.hr_party_id)).notes
      when 'Company' then (Highrise::Company.find(self.hr_party_id)).notes
      else raise 'Unknown party type'
    end
    # TODO: give support to more than 25 notes returned, using pagination with the n parameter as offset
    # TODO: give support to visibility
    # TODO: give support to feeds of updated or deleted notes (currently Highrise does not offer a feed for deleted notes)
  end
  
end
