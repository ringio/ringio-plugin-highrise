class ContactMap < ActiveRecord::Base
  
  belongs_to :user_map
  has_many :note_maps, :dependent => :destroy
  has_many :ring_maps, :dependent => :destroy
  
  validates_presence_of :user_map_id, :rg_contact_id, :hr_party_id, :hr_party_type 
  validates_uniqueness_of :rg_contact_id
  validates_uniqueness_of :hr_party_id, :scope => :hr_party_type
  validates_uniqueness_of :hr_party_type, :scope => :hr_party_id
  
  def hr_resource_party
    start_time = Time.now
    
    case self.hr_party_type 
      when 'Person'
        apiResponse = Highrise::Person.find self.hr_party_id
      when 'Company'
        apiResponse = Highrise::Company.find self.hr_party_id
      else
        raise 'Unknown party type'
    end
    
    ApiOperations::Common.log(:debug,nil,"Highrise (hr_resource_party) API timing: " + ((Time.now - start_time) * 1000).to_s + " ms")
    
    return apiResponse
  end
  
  def rg_resource_contact
    start_time = Time.now
    
    apiResponse = RingioAPI::Contact.find self.rg_contact_id
    
    ApiOperations::Common.log(:debug,nil,"Ringio (rg_resource_contact) API timing: " + ((Time.now - start_time) * 1000).to_s + " ms")
    
    return apiResponse
  end

  def hr_notes
    # get only the Highrise notes that belong this contact (reject notes corresponding to rings)
    notes = case self.hr_party_type
      when 'Person'
        Highrise::Note.find_all_across_pages(:from => '/people/' + self.hr_party_id.to_s + '/notes.xml')
      when 'Company'
        Highrise::Note.find_all_across_pages(:from => '/companies/' + self.hr_party_id.to_s + '/notes.xml')
      else raise 'Unknown party type'
    end
    
    notes.reject{|n| n.body.present? ? n.body.start_with?(ApiOperations::Rings::HR_RING_NOTE_MARK) : false}
  end

end
