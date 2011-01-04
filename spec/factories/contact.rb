Factory.define :ringio_contact, :class => RingioAPI::Contact do |rg_c|
  rg_c.owner_id ApiOperations::TestingInfo::RINGIO_USER_ID
  rg_c.name "Myfirst Andlast"
  rg_c.title "Mytitle"
end