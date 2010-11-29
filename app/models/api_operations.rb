module ApiOperations
  def self.mails_for_select(rg_account_id)
    mails = []
    (RingioAPI::Feed.find(:one, :from => "/feeds/accounts/" + rg_account_id.to_s + "/users" )).updated.each do |rg_user_id|
      mails << [(RingioAPI::User.find(rg_user_id)).email,rg_user_id]
    end
    mails
  end

  def self.set_hr_base(subdomain, user_token)
    Highrise::Base.site = 'https://' + subdomain + '.highrisehq.com' 
    Highrise::Base.user = user_token
  end
  
  def self.empty_hr_base
    Highrise::Base.site = ''
    Highrise::Base.user = ''
  end
  
end