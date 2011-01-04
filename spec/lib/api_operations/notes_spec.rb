require 'spec_helper'

describe ApiOperations::Notes do

  
  before(:each) do
    # create a user_map with no contacts
    @user_map = Factory.create(:user_map)
    @account = @user_map.account
    ApiOperations::Common.empty_rg_contacts @user_map
    ApiOperations::Common.empty_hr_parties @user_map
  end


  it "should create a new Highrise note for a new Ringio note" do
    # initial empty synchronization
    ApiOperations::Common.complete_synchronization
    
    rg_note = create_rg_note
    previous_nm_count = NoteMap.count
    ApiOperations::Common.complete_synchronization
    assert_equal previous_nm_count + 1, ContactMap.count

    nm = NoteMap.find_by_author_user_map_id_and_rg_note_id(@user_map.id,rg_note.id)
    assert_not_nil nm
    
    ApiOperations::Common.set_hr_base @user_map
    hr_note = nm.hr_resource_note
    ApiOperations::Common.empty_hr_base
    
    assert_equal rg_note.body, hr_note.body

  end


  it "should create a new Ringio note for a new Highrise note" do
    # initial empty synchronization
    ApiOperations::Common.complete_synchronization
    
    ApiOperations::Common.set_hr_base @user_map
    hr_note = create_hr_note
    ApiOperations::Common.empty_hr_base
    
    previous_nm_count = NoteMap.count
    ApiOperations::Common.complete_synchronization
    assert_equal previous_nm_count + 1, ContactMap.count

    nm = NoteMap.find_by_author_user_map_id_and_hr_note_id(@user_map.id,hr_note.id)
    assert_not_nil nm
    
    rg_note = nm.rg_resource_note
    
    assert_equal hr_note.body, rg_note.body

  end
  
  
  after(:each) do 
    # remove all the stuff created
    @user_map.destroy
    @account.destroy
  end
  
  
  def create_rg_note
    # we cannot use the factory for this
    rg_note = RingioAPI::Note.new
    rg_note.author_id = ApiOperations::TestingInfo::RINGIO_USER_ID
    rg_note.contact_id = (Factory.create(:ringio_contact)).id
    rg_note.body = "Body of the Ringio note#{rg_note.contact_id}"
    rg_note.save
    rg_note
  end
  
  
  def create_hr_note
    # we cannot use the factory for this, because creating the person associated means that we need
    # the Highrise site and user to be set before starting the spec
    hr_note = Highrise::Note.new
    hr_note.subject_id = (Factory.create(:highrise_person)).id
    hr_note.subject_type = 'Party'
    hr_note.body = "Body of the Highrise note#{hr_note.subject_id}"
    hr_note.save
    hr_note
  end
end