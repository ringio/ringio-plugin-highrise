class RingMap < ActiveRecord::Base

  belongs_to :contact_map
  
  validates_presence_of :contact_map_id, :rg_ring_id, :hr_ring_note_id 
  validates_uniqueness_of :rg_ring_id, :hr_ring_note_id
  
  def hr_resource_ring_note
    start_time = Time.now
    apiResponse = Highrise::Note.find self.hr_ring_note_id
    ApiOperations::Common.log(:debug,nil,"Highrise (hr_resource_ring_note) API timing: " + ((Time.now - start_time) * 1000).to_s + " ms")
    
    return apiResponse
  end
  
  def rg_resource_ring
    start_time = Time.now
    apiResponse = RingioAPI::Ring.find self.rg_ring_id
    ApiOperations::Common.log(:debug,nil,"Ringio (rg_resource_ring) API timing: " + ((Time.now - start_time) * 1000).to_s + " ms")
    
    return apiResponse
  end

end
