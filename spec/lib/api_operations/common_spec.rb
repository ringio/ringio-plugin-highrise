require 'spec_helper'

describe ApiOperations::Common do

  before(:each) do
    # create a user_map with no contacts
    @user_map = Factory.create(:user_map)
    @account = @user_map.account
    
    # empty Ringio contacts
    # TODO: move this to a method
    @user_map.all_rg_contacts_feed.updated.each{|rg_c_id| (RingioAPI::Contact.find(rg_c_id)).destroy}
  
    # empty Highrise Parties
    # TODO: move this to a method
    ApiOperations::Common.set_hr_base @user_map
    feed = @user_map.hr_parties_feed true
    feed[0].each{|hr_person| hr_person.destroy}
    feed[1].each{|hr_company| hr_company.destroy}
    ApiOperations::Common.empty_hr_base
  end

  it "should only update timestamps when synchronizing an empty account" do
    assert_equal 1, 2
  end
  
  after(:each) do 
    # remove all the stuff created
    @user_map.destroy
    @account.destroy
  end
  
end