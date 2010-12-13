class RingMap < ActiveRecord::Base

  belongs_to :contact_map
  
  validates_presence_of :contact_map_id, :rg_ring_id, :hr_note_id 
  validates_uniqueness_of :rg_ring_id, :hr_note_id
  
  def hr_resource_note
    Highrise::Note.find self.hr_note_id
  end
  
  def rg_resource_ring
    RingioAPI::Ring.find self.rg_ring_id
  end

end
