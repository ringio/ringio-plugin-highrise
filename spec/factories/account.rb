Factory.define :account, :class => Account do |a|
  a.rg_account_id ApiOperations::TestingInfo::RINGIO_ACCOUNT_ID
  a.hr_subdomain ApiOperations::TestingInfo::HIGHRISE_SUBDOMAIN
end

