class ContactMap < ActiveRecord::Base
  
  belongs_to :user_map
  
  validates_presence_of :user_map_id, :rg_contact_id, :hr_party_id, :hr_party_type 
  validates_uniqueness_of :rg_contact_id
  validates_uniqueness_of :hr_party_id, :scope => :hr_party_type
  validates_uniqueness_of :hr_party_type, :scope => :hr_party_id
  
end
