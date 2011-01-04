require 'spec_helper'

describe ApiOperations::Contacts do
  
  before(:each) do
    # create a user_map with no contacts
    @user_map = Factory.create(:user_map)
    @account = @user_map.account
    ApiOperations::Common.empty_rg_contacts @user_map
    ApiOperations::Common.empty_hr_parties @user_map
  end

  it "should create a new Highrise person for a new Ringio contact" do
    # initial empty synchronization
    ApiOperations::Common.complete_synchronization
    rg_contact = Factory.create(:ringio_contact)

    previous_cm_count = ContactMap.count
    ApiOperations::Common.complete_synchronization
    assert_equal previous_cm_count + 1, ContactMap.count

    cm = ContactMap.find_by_user_map_id_and_rg_contact_id(@user_map.id,rg_contact.id)
    assert_not_nil cm
    
    hr_person = Highrise::Person.find cm.hr_party_id
    assert_equal rg_contact.name.split(' ')[0], hr_person.first_name
    assert_equal rg_contact.name.split(' ')[1], hr_person.last_name
    assert_equal rg_contact.title, hr_person.title
  end
  
  after(:each) do 
    # remove all the stuff created
    @user_map.destroy
    @account.destroy
  end
  
end