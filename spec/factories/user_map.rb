Factory.define :user_map, :class => UserMap do |um|
  um.association :account, :factory => :account
  um.rg_user_id ApiOperations::TestingInfo::RINGIO_USER_ID
  um.hr_user_token ApiOperations::TestingInfo::HIGHRISE_TOKEN
end