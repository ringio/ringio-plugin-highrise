class Account < ActiveRecord::Base

  has_many :user_maps, :dependent => :destroy
  
  validates_presence_of :rg_account_id, :rg_account_id_hash
  validates_uniqueness_of :rg_account_id, :rg_account_id_hash
  validates_uniqueness_of :hr_subdomain, :allow_blank => true
  
  before_validation do |ac|
    ac.rg_account_id_hash = ApiOperations::Hashing.digest(ac.rg_account_id.to_s + RingioAPI::Base.user.to_s)
  end
    
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
