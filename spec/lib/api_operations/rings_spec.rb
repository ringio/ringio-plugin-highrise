require 'spec_helper'

require 'ringioAPI'

class RingioAPI::Ring < RingioAPI::Base
  def save
      new? ? create : update
  end
end
describe ApiOperations::Rings do

  
  before(:each) do
    # create a user_map with no contacts
    @user_map = Factory.create(:user_map)
    @account = @user_map.account
    ApiOperations::Common.empty_rg_contacts @user_map
    ApiOperations::Common.empty_hr_parties @user_map
  end

  
  it "should create a new Highrise ring note for a new ringio ring" do

    ApiOperations::Common.complete_synchronization

    previous_rm_count = RingMap.count
    @contact = create_contact
    @ring = create_rg_ring
    ApiOperations::Common.complete_synchronization

    assert_equal previous_rm_count + 1, RingMap.count

    destroy_last_ring

  end

  it "should create a new Highrise ring note for a new ringio ring in the initial synchronization" do
    previous_rm_count = RingMap.count
    @contact = create_contact
    @ring = create_rg_ring
    ApiOperations::Common.complete_synchronization

    assert_equal previous_rm_count + 1, RingMap.count
    destroy_last_ring
  end

  it "should NOT create a new Ringio note or ring for a new Highrise ring note" do
    # initial empty synchronization
    ApiOperations::Common.complete_synchronization
    
    ApiOperations::Common.set_hr_base @user_map
    hr_note = create_hr_ring_note
    ApiOperations::Common.empty_hr_base
    
    previous_nm_count = NoteMap.count
    previous_rm_count = RingMap.count
    ApiOperations::Common.complete_synchronization
    assert_equal previous_nm_count, NoteMap.count
    assert_equal previous_rm_count, RingMap.count

    assert_nil NoteMap.find_by_hr_note_id(hr_note.id)
    assert_nil RingMap.find_by_hr_ring_note_id(hr_note.id)
  end

  
  it "in the initial synchronization should NOT create a new Ringio note or ring for a new Highrise ring note" do
    ApiOperations::Common.set_hr_base @user_map
    hr_note = create_hr_ring_note
    ApiOperations::Common.empty_hr_base
    
    previous_nm_count = NoteMap.count
    previous_rm_count = RingMap.count
    ApiOperations::Common.complete_synchronization
    assert_equal previous_nm_count, NoteMap.count
    assert_equal previous_rm_count, RingMap.count

    assert_nil NoteMap.find_by_hr_note_id(hr_note.id)
    assert_nil RingMap.find_by_hr_ring_note_id(hr_note.id)
  end

  
  it "should NOT create a Ringio note or ring for an edited Highrise note" do
    # initial empty synchronization
    ApiOperations::Common.complete_synchronization
    
    ApiOperations::Common.set_hr_base @user_map
    hr_note = create_hr_ring_note
    ApiOperations::Common.empty_hr_base
    
    previous_nm_count = NoteMap.count
    previous_rm_count = RingMap.count
    ApiOperations::Common.complete_synchronization
    assert_equal previous_nm_count, NoteMap.count
    assert_equal previous_rm_count, RingMap.count

    # edit the body as it is a simple change, and use a new variable so as not to modify the initial values
    ApiOperations::Common.set_hr_base @user_map
    aux_hr_note = Highrise::Note.find hr_note.id
    aux_hr_note.body = ApiOperations::Rings::HR_RING_NOTE_MARK + " Edited body"

    aux_hr_note = ApiOperations::Notes.remove_subject_name aux_hr_note
    aux_hr_note.save
    ApiOperations::Common.empty_hr_base

    ApiOperations::Common.complete_synchronization

    assert_equal previous_nm_count, NoteMap.count
    assert_equal previous_rm_count, RingMap.count
    assert_nil NoteMap.find_by_hr_note_id(hr_note.id)
    assert_nil RingMap.find_by_hr_ring_note_id(hr_note.id)
  end

  after(:each) do 
    # remove all the stuff created: everything depends on the account for destruction
    @account.destroy
  end

  def destroy_last_ring
    oldToken = RingioAPI::Base.user
    RingioAPI::Base.user = ApiOperations::TestingInfo::RINGIO_TEST_TOKEN
    @ring.id = RingMap.last.rg_ring_id
    @ring.destroy
    RingioAPI::Base.user = oldToken
  end

  def create_contact
    oldToken = RingioAPI::Base.user
    RingioAPI::Base.user = ApiOperations::TestingInfo::RINGIO_TEST_TOKEN
    @account.save()
    rg_contact = Factory.create(:ringio_contact)
    RingioAPI::Base.user = oldToken
    rg_contact
  end

  def create_rg_ring
    oldToken = RingioAPI::Base.user
    RingioAPI::Base.user = ApiOperations::TestingInfo::RINGIO_TEST_TOKEN
    rg_ring = RingioAPI::Ring.new
    rg_ring.accountId = ApiOperations::TestingInfo::RINGIO_ACCOUNT_ID
    rg_ring.src_person_id = @contact.id
    rg_ring.dst_person_id = RingioAPI::User.find(ApiOperations::TestingInfo::RINGIO_USER_ID).id
    rg_ring.save
    RingioAPI::Base.user = oldToken
    rg_ring
  end
  
  
  def create_hr_ring_note
    # we need this method because we cannot use the factory for this, as creating the person associated means that
    # we need the Highrise site and user to be set before starting the spec
    hr_note = Highrise::Note.new
    hr_note.subject_id = (Factory.create(:highrise_person)).id
    hr_note.subject_type = 'Party'
    hr_note.body = ApiOperations::Rings::HR_RING_NOTE_MARK + "Body of the Highrise note#{hr_note.subject_id}"
    hr_note.save
    hr_note
  end
end