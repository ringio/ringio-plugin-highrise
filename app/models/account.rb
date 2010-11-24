class Account < ActiveRecord::Base

  has_many :user_maps, :dependent => :destroy
  
  validates_presence_of :rg_account_id, :rg_account_token
  validates_uniqueness_of :rg_account_id, :rg_account_token
  
  SYNC_PERIOD_MINUTES = 60

end
