class Account < ActiveRecord::Base

  has_many :user_maps, :dependent => :destroy
  
  validates_presence_of :rg_account_id
  validates_uniqueness_of :rg_account_id
  validates_uniqueness_of :hr_subdomain, :allow_blank => true
    
  # TODO: add support for the "Sync only new data" option
  
end
