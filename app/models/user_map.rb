class UserMap < ActiveRecord::Base

  belongs_to :account
  has_many :contact_maps, :dependent => :destroy
  
  validates_presence_of :account_id, :hr_user_id, :rg_user_id, :hr_user_token 
  validates_uniqueness_of :hr_user_id, :rg_user_id, :hr_user_token

  before_validation do |um|
    user_hr = hr_resource_user
    um.hr_user_id = user_hr ? user_hr.id : nil
  end

  def hr_parties_feed(is_new_user)
    timestamp = is_new_user ? ApiOperations::Common::INITIAL_DATETIME : self.account.hr_parties_last_synchronized_at

    # get only the Highrise people and companies that were created by this user and
    # filter to keep those that were created_at or updated at after the last synchronization datetime
    hr_updated_people = Highrise::Person.find_all_across_pages_since(timestamp).reject{|p| p.author_id != self.hr_user_id}
    hr_updated_companies = Highrise::Company.find_all_across_pages_since(timestamp).reject{|c| c.author_id != self.hr_user_id}

    # get deletions of person and companies, mind that author_id is not provided
    hr_party_deletions = is_new_user ? [] : Highrise::Party.deletions_since(timestamp)

    [hr_updated_people,hr_updated_companies,hr_party_deletions]
  end
  
  def all_rg_contacts_feed
    feed = RingioAPI::Feed.find(
      :one,
      :from => RingioAPI::Feed.prefix + "feeds/users/" + self.rg_user_id.to_s + "/contacts"
    )
  end

  def hr_updated_note_recordings(is_new_user)
    timestamp = is_new_user ? ApiOperations::Common::INITIAL_DATETIME : self.account.hr_notes_last_synchronized_at

    # get only the Highrise recordings for notes created by this user for a contact and
    # filter to keep those that were created at or updated at after the last synchronization datetime
    # and reject the notes corresponding to rings
    Highrise::Recording.find_all_across_pages_since(timestamp).reject do |r|
      (r.type != 'Note') || (r.subject_type != 'Party') || (r.author_id != self.hr_user_id) || r.body.start_with?(ApiOperations::Rings::HR_RING_NOTE_MARK)
    end
  end

  private
    def hr_resource_user
      ApiOperations::Common.set_hr_base self

      begin
        user_hr = Highrise::User.me
      rescue ActiveResource::UnauthorizedAccess => e
        self.errors[:hr_user_token] = I18n.t('user_map.unauthorized_token')
      rescue ActiveResource::ResourceNotFound => e
        self.errors[:hr_user_token] = I18n.t('user_map.unauthorized_token')
      end

      ApiOperations::Common.empty_hr_base
      
      user_hr
    end
  
end
