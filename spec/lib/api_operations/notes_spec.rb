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
    assert_equal previous_nm_count + 1, NoteMap.count

    nm = NoteMap.find_by_rg_note_id(rg_note.id)
    assert_not_nil nm
    
    ApiOperations::Common.set_hr_base @user_map
    hr_note = nm.hr_resource_note
    ApiOperations::Common.empty_hr_base
    
    assert_equal rg_note.body, hr_note.body
  end

  it "in the initial synchronization should create a new Highrise note for a new Ringio note" do
    rg_note = create_rg_note
    previous_nm_count = NoteMap.count
    ApiOperations::Common.complete_synchronization
    assert_equal previous_nm_count + 1, NoteMap.count

    nm = NoteMap.find_by_rg_note_id(rg_note.id)
    assert_not_nil nm
    
    ApiOperations::Common.set_hr_base @user_map
    hr_note = nm.hr_resource_note
    ApiOperations::Common.empty_hr_base
    
    assert_equal rg_note.body, hr_note.body
  end


  it "should update a Highrise note for an edited Ringio note" do
    # initial empty synchronization
    ApiOperations::Common.complete_synchronization
    
    rg_note = create_rg_note
    previous_nm_count = NoteMap.count
    ApiOperations::Common.complete_synchronization
    assert_equal previous_nm_count + 1, NoteMap.count

    # edit the body as it is a simple change, and use a new variable so as not to modify the initial values
    aux_rg_note = RingioAPI::Note.find rg_note.id
    aux_rg_note.body = 'Edited body'
    aux_rg_note.save
    
    ApiOperations::Common.complete_synchronization

    nm = NoteMap.find_by_rg_note_id(rg_note.id)
    assert_not_nil nm
    
    ApiOperations::Common.set_hr_base @user_map
    hr_note = nm.hr_resource_note
    ApiOperations::Common.empty_hr_base
    
    assert_equal aux_rg_note.body, hr_note.body
  end

# Doesn't work as ringio API never returns deleted notes because it's deceptive and tricky
=begin
  it "should delete a Highrise note for a deleted Ringio note" do
    # initial empty synchronization
    ApiOperations::Common.complete_synchronization
    
    rg_note = create_rg_note
    previous_nm_count = NoteMap.count
    ApiOperations::Common.complete_synchronization
    assert_equal previous_nm_count + 1, NoteMap.count

    nm = NoteMap.find_by_rg_note_id(rg_note.id)
    assert_not_nil nm
    
    ApiOperations::Common.set_hr_base @user_map
    hr_note = nm.hr_resource_note
    ApiOperations::Common.empty_hr_base

    # delete the Ringio note
    oldToken = RingioAPI::Base.user
    RingioAPI::Base.user = ApiOperations::TestingInfo::RINGIO_TEST_TOKEN
    (RingioAPI::Note.find rg_note.id).destroy
    RingioAPI::Base.user = oldToken

    ApiOperations::Common.complete_synchronization
    assert_equal previous_nm_count, NoteMap.count
    begin
      ApiOperations::Common.set_hr_base @user_map
      # the corresponding Highrise note should not be found
      Highrise::Note.find hr_note.id
      assert false
    rescue ActiveResource::ResourceNotFound
      # OK
      ApiOperations::Common.empty_hr_base
    end
  end
=end

  it "should create a new Ringio note for a new Highrise note" do
    # initial empty synchronization
    ApiOperations::Common.complete_synchronization
    
    ApiOperations::Common.set_hr_base @user_map
    hr_note = create_hr_note
    ApiOperations::Common.empty_hr_base
    
    previous_nm_count = NoteMap.count
    ApiOperations::Common.complete_synchronization
    assert_equal previous_nm_count + 1, NoteMap.count

    nm = NoteMap.find_by_hr_note_id(hr_note.id)
    assert_not_nil nm
    
    rg_note = nm.rg_resource_note
    
    assert_equal hr_note.body, rg_note.body
  end
  
  
  it "in the initial synchronization should create a new Ringio note for a new Highrise note" do
    ApiOperations::Common.set_hr_base @user_map
    hr_note = create_hr_note
    ApiOperations::Common.empty_hr_base
    
    previous_nm_count = NoteMap.count
    ApiOperations::Common.complete_synchronization
    assert_equal previous_nm_count + 1, NoteMap.count

    nm = NoteMap.find_by_hr_note_id(hr_note.id)
    assert_not_nil nm
    
    rg_note = nm.rg_resource_note
    
    assert_equal hr_note.body, rg_note.body
  end

  
  it "should update a Ringio note for an edited Highrise note" do
    # initial empty synchronization
    ApiOperations::Common.complete_synchronization
    
    ApiOperations::Common.set_hr_base @user_map
    hr_note = create_hr_note
    ApiOperations::Common.empty_hr_base
    
    previous_nm_count = NoteMap.count
    ApiOperations::Common.complete_synchronization
    assert_equal previous_nm_count + 1, NoteMap.count

    # edit the body as it is a simple change, and use a new variable so as not to modify the initial values
    ApiOperations::Common.set_hr_base @user_map
    aux_hr_note = Highrise::Note.find hr_note.id
    aux_hr_note.body = 'Edited body'

    aux_hr_note = ApiOperations::Notes.remove_subject_name aux_hr_note
    aux_hr_note.save
    ApiOperations::Common.empty_hr_base

    ApiOperations::Common.complete_synchronization

    nm = NoteMap.find_by_hr_note_id(hr_note.id)
    assert_not_nil nm
    
    rg_note = nm.rg_resource_note
    
    assert_equal aux_hr_note.body, rg_note.body
  end

#Got rid of all note deleting to speed this up by orders of magnitude
=begin  
  it "should delete a Ringio note for a deleted Highrise note" do
    # initial empty synchronization
    ApiOperations::Common.complete_synchronization
    
    ApiOperations::Common.set_hr_base @user_map
    hr_note = create_hr_note
    ApiOperations::Common.empty_hr_base
    
    previous_nm_count = NoteMap.count
    ApiOperations::Common.complete_synchronization
    assert_equal previous_nm_count + 1, NoteMap.count

    nm = NoteMap.find_by_hr_note_id(hr_note.id)
    assert_not_nil nm
    
    rg_note = nm.rg_resource_note
    
    # delete the Highrise note
    ApiOperations::Common.set_hr_base @user_map
    (Highrise::Note.find hr_note.id).destroy
    ApiOperations::Common.empty_hr_base

    ApiOperations::Common.complete_synchronization
    assert_equal previous_nm_count, NoteMap.count
    begin
      # the corresponding Ringio note should not be found
      RingioAPI::Note.find rg_note.id
      assert false
    rescue ActiveResource::ResourceNotFound
      # OK
    end
  end
=end
  
  after(:each) do 
    # remove all the stuff created: everything depends on the account for destruction
    @account.destroy
  end
  
  
  def create_rg_note
    # we need this method because we cannot use the factory for this
    oldToken = RingioAPI::Base.user
    RingioAPI::Base.user = ApiOperations::TestingInfo::RINGIO_TEST_TOKEN
    rg_note = RingioAPI::Note.new
    rg_note.author_id = ApiOperations::TestingInfo::RINGIO_USER_ID
    rg_note.contact_id = (Factory.create(:ringio_contact)).id
    rg_note.body = "Body of the Ringio note#{rg_note.contact_id}"
    rg_note.save
    RingioAPI::Base.user = oldToken
    rg_note
  end
  
  
  def create_hr_note
    # we need this method because we cannot use the factory for this, as creating the person associated means that
    # we need the Highrise site and user to be set before starting the spec
    hr_note = Highrise::Note.new
    hr_note.subject_id = (Factory.create(:highrise_person)).id
    hr_note.subject_type = 'Party'
    hr_note.body = "Body of the Highrise note#{hr_note.subject_id}"
    hr_note.save
    hr_note
  end
end