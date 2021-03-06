class Account < ActiveRecord::Base

  has_many :user_maps, :dependent => :destroy
  
  validates_presence_of :rg_account_id, :rg_account_id_hash
  validates_uniqueness_of :rg_account_id, :rg_account_id_hash
  validates_uniqueness_of :hr_subdomain, :allow_blank => true
  
  before_validation do |ac|
    ac.rg_account_id_hash = ApiOperations::Hashing.digest(ac.rg_account_id.to_s + RingioAPI::Base.user.to_s)
  end
    
  def rg_contacts_feed
    rg_contacts_last_timestamp = Time.now
    feed = RingioAPI::Feed.find(
      :one,
      :from => RingioAPI::Feed.prefix + "feeds/accounts/" + self.rg_account_id.to_s + "/contacts",
      :params => { :since => ApiOperations::Common.fixTime(self.rg_contacts_last_timestamp) }
    )
  end

  def all_rg_notes_feed
    feed = RingioAPI::Feed.find(
      :one,
      :from => RingioAPI::Feed.prefix + "feeds/accounts/" + self.rg_account_id.to_s + "/notes"
    )
  end
  
  def rg_notes_feed
    feed = RingioAPI::Feed.find(
      :one,
      :from => RingioAPI::Feed.prefix + "feeds/accounts/" + self.rg_account_id.to_s + "/notes",
      :params => { :since => ApiOperations::Common.fixTime(self.rg_notes_last_timestamp) }
    )
  end
  
  def all_rg_rings_feed
    feed = RingioAPI::Feed.find(
      :one,
      :from => RingioAPI::Feed.prefix + "feeds/accounts/" + self.rg_account_id.to_s + "/rings"
    )
  end

  def rg_rings_feed
    feed = RingioAPI::Feed.find(
      :one,
      :from => RingioAPI::Feed.prefix + "feeds/accounts/" + self.rg_account_id.to_s + "/rings",
      :params => { :since => ApiOperations::Common.fixTime(self.rg_rings_last_timestamp) }
    )
  end

  def rg_resource_account
    RingioAPI::Account.find self.rg_account_id
  end


end
