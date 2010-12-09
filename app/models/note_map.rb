class NoteMap < ActiveRecord::Base

  belongs_to :contact_map
  
  validates_presence_of :contact_map_id, :rg_note_id, :hr_note_id 
  validates_uniqueness_of :rg_note_id, :hr_note_id

end
