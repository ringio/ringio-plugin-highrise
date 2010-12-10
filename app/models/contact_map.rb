class ContactMap < ActiveRecord::Base
  
  belongs_to :user_map
  has_many :note_maps, :dependent => :destroy
  
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
  
  def rg_notes_feed
    # TODO: give support to note visibility
    feed = RingioAPI::Feed.find(
      :one,
      :from => RingioAPI::Feed.prefix + "feeds/contacts/" + self.rg_contact_id.to_s + "/notes",
      :params => { :since => self.rg_last_timestamp }
    )
  end
  
  def hr_notes_feed
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
