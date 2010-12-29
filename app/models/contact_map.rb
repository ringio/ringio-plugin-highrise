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
    # get only the Highrise notes that belong this contact (reject notes corresponding to rings)
    case self.hr_party_type
      when 'Person' then Highrise::Note.find_all_across_pages(:from => '/people/' + self.hr_party_id.to_s + '/notes.xml').reject{|n| n.body[0,40] == 'RING - DO NOT CHANGE OR DELETE THIS NOTE'}
      when 'Company' then Highrise::Note.find_all_across_pages(:from => '/companies/' + self.hr_party_id.to_s + '/notes.xml').reject{|n| n.body[0,40] == 'RING - DO NOT CHANGE OR DELETE THIS NOTE'}
      else raise 'Unknown party type'
    end
    # TODO: give support to visibility
  end

  def hr_updated_note_recordings(is_new_user)
    timestamp = is_new_user ? ApiOperations::Common::INITIAL_DATETIME : self.user_map.account.hr_notes_last_synchronized_at
    
    # get only the Highrise recordings for notes for the current contact and
    # filter to keep those that were created_at or updated at after the last synchronization datetime
    # and reject the notes corresponding to rings
    Highrise::Recording.find_all_across_pages_since(timestamp).reject do |r|
      (r.type != 'Note') || (r.subject_type != 'Party') || (r.subject_id != self.hr_party_id) || (r.body[0,40] == 'RING - DO NOT CHANGE OR DELETE THIS NOTE')
    end
  end
  
end
