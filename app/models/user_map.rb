class UserMap < ActiveRecord::Base

  belongs_to :account
  has_many :contact_maps, :dependent => :destroy
  
  validates_presence_of :account_id, :hr_user_id, :rg_user_id, :hr_user_token 
  validates_uniqueness_of :hr_user_id, :rg_user_id, :hr_user_token

  before_validation do |um|
    um.hr_user_id = hr_user ? hr_user.id : nil
  end

  before_save do |um|
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
  
  def update_hr_last_synchronized_at
    # create a fake contact, set timestamp to the created_at in the response and then destroy that fake contact
    timestamp_person = Highrise::Person.new(:first_name => 'Ringio Check')
    timestamp_person.save
    self.hr_last_synchronized_at = timestamp_person.created_at
    timestamp_person.destroy
  end
  
  private
    def hr_user
      ApiOperations.set_hr_base self

      begin
        user_hr = Highrise::User.me
      rescue ActiveResource::UnauthorizedAccess => e
        self.errors[:hr_user_token] = I18n.t('user_map.unauthorized_token')
      end

      ApiOperations.empty_hr_base
      
      user_hr
    end

end
