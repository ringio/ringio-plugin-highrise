class UserMap < ActiveRecord::Base

  belongs_to :account
  
  validates_presence_of :rg_user_id, :hr_user_token, :account_id
  validates_uniqueness_of :rg_user_id, :hr_user_token
  
  before_save do |um|
    um.hr_user_id = hr_user.id
  end
  
  private
    def hr_user
      ApiOperations.set_hr_base(self.account.hr_subdomain, self.hr_user_token)

      user_hr = Highrise::User.me

      ApiOperations.empty_hr_base
      
      user_hr
    end

end
