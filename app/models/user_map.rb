class UserMap < ActiveRecord::Base

  belongs_to :account
  
  validates_presence_of :rg_user_id, :hr_user_token, :account_id
  validates_uniqueness_of :rg_user_id, :hr_user_token

  after_destroy do |um|
    # if the master user is destroyed, choose a new master user
    if um.master_user
      new_master = UserMap.find_by_account_id um.account_id
      if new_master
        unless new_master.master_user
          new_master.master_user = true
          new_master.save
        end
      end
    end
  end
  
  before_save do |um|
    um.hr_user_id = hr_user.id
    # keep only 1 master user per account
    if um.master_user
      # careful with these methods, no validations or callbacks are used
      if um.id
        UserMap.update_all(["master_user = ?", false], ["account_id = ? AND id != ? AND master_user = ?", um.account_id, um.id, true])
      else
        UserMap.update_all(["master_user = ?", false], ["account_id = ? AND master_user = ?", um.account_id, true])
      end
    else
      current_other_masters = (UserMap.find_all_by_account_id_and_master_user(um.account_id,true)).reject{|mu| mu.id == um.id}
      if current_other_masters.blank?
        um.master_user = true
      end
    end
  end
  
  private
    def hr_user
      ApiOperations.set_hr_base self.account.hr_subdomain, self.hr_user_token

      user_hr = Highrise::User.me

      ApiOperations.empty_hr_base
      
      user_hr
    end

end
