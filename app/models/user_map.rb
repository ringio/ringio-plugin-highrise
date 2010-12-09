class UserMap < ActiveRecord::Base

  belongs_to :account
  has_many :contact_maps, :dependent => :destroy
  
  validates_presence_of :account_id, :hr_user_id, :rg_user_id, :hr_user_token 
  validates_uniqueness_of :hr_user_id, :rg_user_id, :hr_user_token

  before_validation do |um|
    um.hr_user_id = hr_resource_user ? hr_resource_user.id : nil
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
  
  def rg_contacts_feed
    # TODO: give support to shared contacts (group to Client in Ringio)
    feed = RingioAPI::Feed.find(
      :one,
      :from => RingioAPI::Feed.prefix + "feeds/users/" + self.rg_user_id.to_s + "/contacts",
      :params => { :since => self.rg_last_timestamp }
    )
    self.rg_last_timestamp = feed.timestamp
    feed
  end
  
  def hr_parties_feed
    # get only the Highrise people and companies that were created by this user and
    # filter to keep those that were created_at or updated at after the last synchronization datetime
    hr_updated_people = Highrise::Person.find_all_across_pages_since(self.hr_last_synchronized_at).reject{|p| p.author_id != self.hr_user_id}
    hr_updated_companies = Highrise::Company.find_all_across_pages_since(self.hr_last_synchronized_at).reject{|c| c.author_id != self.hr_user_id}

    # TODO: give support to shared contacts (set the group to Client in Ringio)

    # get deletions of person and companies, mind that author_id is not provided
    hr_party_deletions = Highrise::Party.deletions_since(self.hr_last_synchronized_at)

    update_hr_last_synchronized_at
    
    [hr_updated_people,hr_updated_companies,hr_party_deletions]
  end
  
  private
    def hr_resource_user
      ApiOperations::Common.set_hr_base self

      begin
        user_hr = Highrise::User.me
      rescue ActiveResource::UnauthorizedAccess => e
        self.errors[:hr_user_token] = I18n.t('user_map.unauthorized_token')
      end

      ApiOperations::Common.empty_hr_base
      
      user_hr
    end
  
    def update_hr_last_synchronized_at
      # create a fake contact, set timestamp to the created_at in the response and then destroy that fake contact
      timestamp_person = Highrise::Person.new(:first_name => 'Ringio Check')
      timestamp_person.save
      self.hr_last_synchronized_at = timestamp_person.created_at
      timestamp_person.destroy
    end

end
