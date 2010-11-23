class Account < ActiveRecord::Base

  has_many :user_maps, :dependent => :destroy
  
  SYNC_PERIOD_MINUTES = 60

end
