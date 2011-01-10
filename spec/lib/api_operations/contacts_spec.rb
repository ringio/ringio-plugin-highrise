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
    
    ApiOperations::Common.set_hr_base @user_map
    hr_person = cm.hr_resource_party
    ApiOperations::Common.empty_hr_base
    
    assert_equal rg_contact.name.split(' ')[0], hr_person.first_name
    assert_equal rg_contact.name.split(' ')[1], hr_person.last_name
    assert_equal rg_contact.title, hr_person.title

    # 3 Ringio contact data: email, telephone and address (although addresses are not synchronized from Ringio to Highrise)
    assert_equal 3, rg_contact.data.length
    assert_equal 1, hr_person.contact_data.email_addresses.length
    assert_equal 1, hr_person.contact_data.phone_numbers.length
    rg_contact.data.each do |datum|
      if datum.type == 'email'
        assert_equal datum.value, hr_person.contact_data.email_addresses.first.address
        assert_equal datum.rel, hr_person.contact_data.email_addresses.first.location.downcase
      elsif datum.type == 'telephone'
        assert_equal datum.value, hr_person.contact_data.phone_numbers.first.number
        assert_equal datum.rel, hr_person.contact_data.phone_numbers.first.location.downcase
      elsif datum.type != 'address'
        # no other datum type was created in the factory
        assert false
      end
    end
  end


  it "in the initial synchronization should create a new Highrise person for a new Ringio contact" do
    rg_contact = Factory.create(:ringio_contact)
    previous_cm_count = ContactMap.count
    ApiOperations::Common.complete_synchronization
    assert_equal previous_cm_count + 1, ContactMap.count

    cm = ContactMap.find_by_user_map_id_and_rg_contact_id(@user_map.id,rg_contact.id)
    assert_not_nil cm
    
    ApiOperations::Common.set_hr_base @user_map
    hr_person = cm.hr_resource_party
    ApiOperations::Common.empty_hr_base
    
    assert_equal rg_contact.name.split(' ')[0], hr_person.first_name
    assert_equal rg_contact.name.split(' ')[1], hr_person.last_name
    assert_equal rg_contact.title, hr_person.title

    # 3 Ringio contact data: email, telephone and address (although addresses are not synchronized from Ringio to Highrise)
    assert_equal 3, rg_contact.data.length
    assert_equal 1, hr_person.contact_data.email_addresses.length
    assert_equal 1, hr_person.contact_data.phone_numbers.length
    rg_contact.data.each do |datum|
      if datum.type == 'email'
        assert_equal datum.value, hr_person.contact_data.email_addresses.first.address
        assert_equal datum.rel, hr_person.contact_data.email_addresses.first.location.downcase
      elsif datum.type == 'telephone'
        assert_equal datum.value, hr_person.contact_data.phone_numbers.first.number
        assert_equal datum.rel, hr_person.contact_data.phone_numbers.first.location.downcase
      elsif datum.type != 'address'
        # no other datum type was created in the factory
        assert false
      end
    end
  end


  it "should update a Highrise person for an edited Ringio contact" do
    # initial empty synchronization
    ApiOperations::Common.complete_synchronization
    
    rg_contact = Factory.create(:ringio_contact)
    previous_cm_count = ContactMap.count
    ApiOperations::Common.complete_synchronization
    assert_equal previous_cm_count + 1, ContactMap.count
   
    # edit the title as it is a simple change, and use a new variable so as not to modify the initial values
    aux_rg_contact = RingioAPI::Contact.find rg_contact.id
    aux_rg_contact.title = 'Edited title'
    aux_rg_contact.save
    
    ApiOperations::Common.complete_synchronization
    
    cm = ContactMap.find_by_user_map_id_and_rg_contact_id(@user_map.id,rg_contact.id)
    assert_not_nil cm
    
    ApiOperations::Common.set_hr_base @user_map
    hr_person = cm.hr_resource_party
    ApiOperations::Common.empty_hr_base
    
    assert_equal rg_contact.name.split(' ')[0], hr_person.first_name
    assert_equal rg_contact.name.split(' ')[1], hr_person.last_name
    assert_equal aux_rg_contact.title, hr_person.title

    # 3 Ringio contact data: email, telephone and address (although addresses are not synchronized from Ringio to Highrise)
    assert_equal 3, rg_contact.data.length
    assert_equal 1, hr_person.contact_data.email_addresses.length
    assert_equal 1, hr_person.contact_data.phone_numbers.length
    rg_contact.data.each do |datum|
      if datum.type == 'email'
        assert_equal datum.value, hr_person.contact_data.email_addresses.first.address
        assert_equal datum.rel, hr_person.contact_data.email_addresses.first.location.downcase
      elsif datum.type == 'telephone'
        assert_equal datum.value, hr_person.contact_data.phone_numbers.first.number
        assert_equal datum.rel, hr_person.contact_data.phone_numbers.first.location.downcase
      elsif datum.type != 'address'
        # no other datum type was created in the factory
        assert false
      end
    end
  end


  it "should delete a Highrise person for a deleted Ringio contact" do
    # initial empty synchronization
    ApiOperations::Common.complete_synchronization
    
    rg_contact = Factory.create(:ringio_contact)
    previous_cm_count = ContactMap.count
    ApiOperations::Common.complete_synchronization
    assert_equal previous_cm_count + 1, ContactMap.count

    ApiOperations::Common.complete_synchronization
    
    cm = ContactMap.find_by_user_map_id_and_rg_contact_id(@user_map.id,rg_contact.id)
    assert_not_nil cm
    
    ApiOperations::Common.set_hr_base @user_map
    hr_person = cm.hr_resource_party
    ApiOperations::Common.empty_hr_base

    # delete the Ringio contact
    (RingioAPI::Contact.find rg_contact.id).destroy

    ApiOperations::Common.complete_synchronization
    assert_equal previous_cm_count, ContactMap.count
    begin
      ApiOperations::Common.set_hr_base @user_map
      # the corresponding Highrise person should not be found
      Highrise::Person.find hr_person.id
      assert false
    rescue ActiveResource::ResourceNotFound
      # OK
      ApiOperations::Common.empty_hr_base
    end
  end


  it "should create a new Ringio contact for a new Highrise person" do
    # initial empty synchronization
    ApiOperations::Common.complete_synchronization
    
    ApiOperations::Common.set_hr_base @user_map
    hr_person = create_full_hr_person
    ApiOperations::Common.empty_hr_base

    previous_cm_count = ContactMap.count
    ApiOperations::Common.complete_synchronization
    assert_equal previous_cm_count + 1, ContactMap.count

    cm = ContactMap.find_by_user_map_id_and_hr_party_id_and_hr_party_type(@user_map.id,hr_person.id,'Person')
    assert_not_nil cm
    rg_contact = cm.rg_resource_contact
    
    assert_equal hr_person.first_name, rg_contact.name.split(' ')[0]
    assert_equal hr_person.last_name, rg_contact.name.split(' ')[1]
    assert_equal hr_person.title, rg_contact.title

    # 4 Ringio contact data: Highrise URL, email, telephone and address
    assert_equal 4, rg_contact.data.length
    assert_equal 1, hr_person.contact_data.email_addresses.length
    assert_equal 1, hr_person.contact_data.phone_numbers.length
    assert_equal 1, hr_person.contact_data.addresses.length
    rg_contact.data.each do |datum|
      if datum.type == 'email'
        assert_equal hr_person.contact_data.email_addresses.first.address, datum.value
        assert_equal hr_person.contact_data.email_addresses.first.location.downcase, datum.rel
      elsif datum.type == 'telephone'
        assert_equal hr_person.contact_data.phone_numbers.first.number, datum.value
        assert_equal hr_person.contact_data.phone_numbers.first.location.downcase, datum.rel
      elsif datum.type == 'website'
        ApiOperations::Common.set_hr_base @user_map
        url_hr_party = Highrise::Base.site.to_s + '/parties/' + hr_person.id.to_s + '-' + rg_contact.name.downcase.gsub(' ','-')
        ApiOperations::Common.empty_hr_base
        assert_equal url_hr_party, datum.value
      elsif datum.type == 'address'
        assert_equal hr_person.contact_data.addresses.first.country, datum.value
        assert_equal hr_person.contact_data.addresses.first.location.downcase, datum.rel
      else
        # no other datum type was created in the factory
        assert false
      end
    end
  end

  
  it "in the initial synchronization should create a new Ringio contact for a new Highrise person" do
    ApiOperations::Common.set_hr_base @user_map
    hr_person = create_full_hr_person
    ApiOperations::Common.empty_hr_base

    previous_cm_count = ContactMap.count
    ApiOperations::Common.complete_synchronization
    assert_equal previous_cm_count + 1, ContactMap.count

    cm = ContactMap.find_by_user_map_id_and_hr_party_id_and_hr_party_type(@user_map.id,hr_person.id,'Person')
    assert_not_nil cm
    rg_contact = cm.rg_resource_contact
    
    assert_equal hr_person.first_name, rg_contact.name.split(' ')[0]
    assert_equal hr_person.last_name, rg_contact.name.split(' ')[1]
    assert_equal hr_person.title, rg_contact.title

    # 4 Ringio contact data: Highrise URL, email, telephone and address
    assert_equal 4, rg_contact.data.length
    assert_equal 1, hr_person.contact_data.email_addresses.length
    assert_equal 1, hr_person.contact_data.phone_numbers.length
    assert_equal 1, hr_person.contact_data.addresses.length
    rg_contact.data.each do |datum|
      if datum.type == 'email'
        assert_equal hr_person.contact_data.email_addresses.first.address, datum.value
        assert_equal hr_person.contact_data.email_addresses.first.location.downcase, datum.rel
      elsif datum.type == 'telephone'
        assert_equal hr_person.contact_data.phone_numbers.first.number, datum.value
        assert_equal hr_person.contact_data.phone_numbers.first.location.downcase, datum.rel
      elsif datum.type == 'website'
        ApiOperations::Common.set_hr_base @user_map
        url_hr_party = Highrise::Base.site.to_s + '/parties/' + hr_person.id.to_s + '-' + rg_contact.name.downcase.gsub(' ','-')
        ApiOperations::Common.empty_hr_base
        assert_equal url_hr_party, datum.value
      elsif datum.type == 'address'
        assert_equal hr_person.contact_data.addresses.first.country, datum.value
        assert_equal hr_person.contact_data.addresses.first.location.downcase, datum.rel
      else
        # no other datum type was created in the factory
        assert false
      end
    end
  end


  it "should update a Ringio contact for an edited Highrise person" do
    # initial empty synchronization
    ApiOperations::Common.complete_synchronization
    
    ApiOperations::Common.set_hr_base @user_map
    hr_person = create_full_hr_person
    ApiOperations::Common.empty_hr_base

    previous_cm_count = ContactMap.count
    ApiOperations::Common.complete_synchronization
    assert_equal previous_cm_count + 1, ContactMap.count

    # edit the title as it is a simple change, and use a new variable so as not to modify the initial values
    ApiOperations::Common.set_hr_base @user_map
    aux_hr_person = Highrise::Person.find hr_person.id
    aux_hr_person.title = 'Edited title'
    aux_hr_person.save
    ApiOperations::Common.empty_hr_base

    ApiOperations::Common.complete_synchronization

    cm = ContactMap.find_by_user_map_id_and_hr_party_id_and_hr_party_type(@user_map.id,hr_person.id,'Person')
    assert_not_nil cm
    rg_contact = cm.rg_resource_contact

    assert_equal hr_person.first_name, rg_contact.name.split(' ')[0]
    assert_equal hr_person.last_name, rg_contact.name.split(' ')[1]
    assert_equal aux_hr_person.title, rg_contact.title

    # 4 Ringio contact data: Highrise URL, email, telephone and address
    assert_equal 4, rg_contact.data.length
    assert_equal 1, hr_person.contact_data.email_addresses.length
    assert_equal 1, hr_person.contact_data.phone_numbers.length
    assert_equal 1, hr_person.contact_data.addresses.length
    rg_contact.data.each do |datum|
      if datum.type == 'email'
        assert_equal hr_person.contact_data.email_addresses.first.address, datum.value
        assert_equal hr_person.contact_data.email_addresses.first.location.downcase, datum.rel
      elsif datum.type == 'telephone'
        assert_equal hr_person.contact_data.phone_numbers.first.number, datum.value
        assert_equal hr_person.contact_data.phone_numbers.first.location.downcase, datum.rel
      elsif datum.type == 'website'
        ApiOperations::Common.set_hr_base @user_map
        url_hr_party = Highrise::Base.site.to_s + '/parties/' + hr_person.id.to_s + '-' + rg_contact.name.downcase.gsub(' ','-')
        ApiOperations::Common.empty_hr_base
        assert_equal url_hr_party, datum.value
      elsif datum.type == 'address'
        assert_equal hr_person.contact_data.addresses.first.country, datum.value
        assert_equal hr_person.contact_data.addresses.first.location.downcase, datum.rel
      else
        # no other datum type was created in the factory
        assert false
      end
    end
  end

  
  it "should delete a Ringio contact for a deleted Highrise person" do
    # initial empty synchronization
    ApiOperations::Common.complete_synchronization
    
    ApiOperations::Common.set_hr_base @user_map
    hr_person = create_full_hr_person
    ApiOperations::Common.empty_hr_base

    previous_cm_count = ContactMap.count
    ApiOperations::Common.complete_synchronization
    assert_equal previous_cm_count + 1, ContactMap.count

    ApiOperations::Common.complete_synchronization

    cm = ContactMap.find_by_user_map_id_and_hr_party_id_and_hr_party_type(@user_map.id,hr_person.id,'Person')
    assert_not_nil cm
    rg_contact = cm.rg_resource_contact
    
    # delete the Highrise person
    ApiOperations::Common.set_hr_base @user_map
    (Highrise::Person.find hr_person.id).destroy
    ApiOperations::Common.empty_hr_base

    ApiOperations::Common.complete_synchronization
    assert_equal previous_cm_count, ContactMap.count
    begin
      # the corresponding Ringio contact should not be found
      RingioAPI::Contact.find rg_contact.id
      assert false
    rescue ActiveResource::ResourceNotFound
      # OK
    end
  end
  
  
  after(:each) do 
    # remove all the stuff created: everything depends on the account for destruction
    @account.destroy
  end

  
  def create_full_hr_person
    # we need this method because the factory cannot save in the middle of the process to get the ContactData structure
    hr_person = Factory.create(:highrise_person)
    hr_person.contact_data.email_addresses = [Highrise::Person::ContactData::EmailAddress.new(:address => 'mailhrwork@example.com', :location => 'Work')]
    hr_person.contact_data.phone_numbers = [Highrise::Person::ContactData::PhoneNumber.new(:number => '1234567890', :location => 'Home')]
    hr_person.contact_data.addresses = [Highrise::Person::ContactData::Address.new(:country => 'United States', :location => 'Work')]
    hr_person.save
    hr_person
  end
  
end