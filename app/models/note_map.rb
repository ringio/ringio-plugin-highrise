class NoteMap < ActiveRecord::Base

  belongs_to :contact_map
  
  validates_presence_of :contact_map_id, :author_user_map_id, :rg_note_id, :hr_note_id 
  validates_uniqueness_of :rg_note_id, :hr_note_id
  
  def hr_resource_note
    start_time = Time.now
    apiResponse = Highrise::Note.find self.hr_note_id
    ApiOperations::Common.log(:debug,nil,"Highrise (hr_resource_note) API timing: " + ((Time.now - start_time) * 1000).to_s + " ms")
    
    return apiResponse
  end
  
  def rg_resource_note
    start_time = Time.now
    apiResponse = RingioAPI::Note.find self.rg_note_id
    ApiOperations::Common.log(:debug,nil,"Ringio (rg_resource_note) API timing: " + ((Time.now - start_time) * 1000).to_s + " ms")
    
    return apiResponse
  end

end
