Factory.define :account, :class => Account do |a|
  a.rg_account_id ApiOperations::TestingInfo::RINGIO_ACCOUNT_ID
  a.hr_subdomain ApiOperations::TestingInfo::HIGHRISE_SUBDOMAIN
end

Factory.define :user_map, :class => UserMap do |um|
  um.association :account, :factory => :account
  um.rg_user_id ApiOperations::TestingInfo::RINGIO_USER_ID
  um.hr_user_token ApiOperations::TestingInfo::HIGHRISE_TOKEN
end

Factory.define :ringio_contact, :class => RingioAPI::Contact do |rg_c|
  rg_c.owner_id ApiOperations::TestingInfo::RINGIO_USER_ID
  rg_c.sequence(:name){|n| "MyRgfirst#{n} AndRglast#{n}"}
  rg_c.sequence(:title){|n| "MyRgtitle#{n}"}
  rg_c.data [RingioAPI::Contact::Datum.new(:value => 'mailrgwork@example.com', :is_primary => nil, :rel => 'work', :type => 'email'),
             RingioAPI::Contact::Datum.new(:value => '1234567890', :is_primary => nil, :rel => 'mobile', :type => 'telephone')]
end

Factory.define :highrise_person, :class => Highrise::Person do |hr_p|
  hr_p.sequence(:first_name){|n| "MyHrfirst#{n}"}
  hr_p.sequence(:last_name){|n| "AndHrlast#{n}"}  
  hr_p.sequence(:title){|n| "MyHrtitle#{n}"}
end
