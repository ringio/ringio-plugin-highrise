class Account < ActiveRecord::Base

  has_many :user_maps, :dependent => :destroy
  
  validates_presence_of :rg_account_id
  validates_uniqueness_of :rg_account_id
  validates_uniqueness_of :hr_subdomain, :allow_blank => true
    
  # TODO: add support for the "Sync only new data" option
  
  def rg_contacts_feed
    # TODO: give support to shared contacts (group to Client in Ringio)
    feed = RingioAPI::Feed.find(
      :one,
      :from => RingioAPI::Feed.prefix + "feeds/accounts/" + self.rg_account_id.to_s + "/contacts",
      :params => { :since => self.rg_contacts_last_timestamp }
    )
  end
  
  def rg_notes_feed
    # TODO: give support to shared contacts (group to Client in Ringio)
    feed = RingioAPI::Feed.find(
      :one,
      :from => RingioAPI::Feed.prefix + "feeds/accounts/" + self.rg_account_id.to_s + "/notes",
      :params => { :since => self.rg_notes_last_timestamp }
    )
  end
  
  def rg_rings_feed
    # TODO: give support to shared contacts (group to Client in Ringio)
    feed = RingioAPI::Feed.find(
      :one,
      :from => RingioAPI::Feed.prefix + "feeds/accounts/" + self.rg_account_id.to_s + "/rings",
      :params => { :since => self.rg_rings_last_timestamp }
    )
  end

end
