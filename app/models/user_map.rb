class UserMap < ActiveRecord::Base

  belongs_to :account
  
  validates_presence_of :hr_user_id, :rg_user_id, :hr_user_token
  validates_uniqueness_of :hr_user_id, :rg_user_id, :hr_user_token

end
