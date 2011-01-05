require 'spec_helper'

describe ApiOperations::Common do

  before(:each) do
    # create a user_map with no contacts
    @user_map = Factory.create(:user_map)
    @account = @user_map.account
    ApiOperations::Common.empty_rg_contacts @user_map
    ApiOperations::Common.empty_hr_parties @user_map
  end

  it "should only update timestamps when synchronizing an empty account" do
    ApiOperations::Common.complete_synchronization
    @account.reload
    @user_map.reload

    # check there are no contact maps
    assert_equal 0, @user_map.contact_maps.count
    # check there are no note maps
    assert_equal 0, @user_map.contact_maps.inject(0){|total,cm| total + cm.note_maps.count} 
    # check there are no ring maps
    assert_equal 0, @user_map.contact_maps.inject(0){|total,cm| total + cm.ring_maps.count}
    
    # check that the timestamps have increased
    assert @account.rg_contacts_last_timestamp > ApiOperations::Common::INITIAL_MS_DATETIME
    assert @account.rg_notes_last_timestamp > ApiOperations::Common::INITIAL_MS_DATETIME
    assert @account.rg_rings_last_timestamp > ApiOperations::Common::INITIAL_MS_DATETIME
    assert @account.hr_parties_last_synchronized_at > ApiOperations::Common::INITIAL_DATETIME
    assert @account.hr_notes_last_synchronized_at > ApiOperations::Common::INITIAL_DATETIME
    assert @account.hr_ring_notes_last_synchronized_at > ApiOperations::Common::INITIAL_DATETIME
  end
  
  after(:each) do 
    # remove all the stuff created: everything depends on the account for destruction
    @account.destroy
  end

end