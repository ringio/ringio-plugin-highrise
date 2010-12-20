# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20101213164155) do

  create_table "accounts", :force => true do |t|
    t.integer  "rg_account_id"
    t.string   "hr_subdomain"
    t.integer  "rg_contacts_last_timestamp",         :default => 1
    t.integer  "rg_notes_last_timestamp",            :default => 1
    t.integer  "rg_rings_last_timestamp",            :default => 1
    t.datetime "hr_parties_last_synchronized_at",    :default => '1900-01-01 00:14:44'
    t.datetime "hr_notes_last_synchronized_at",      :default => '1900-01-01 00:14:44'
    t.datetime "hr_ring_notes_last_synchronized_at", :default => '1900-01-01 00:14:44'
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "contact_maps", :force => true do |t|
    t.integer  "user_map_id"
    t.integer  "rg_contact_id"
    t.integer  "hr_party_id"
    t.string   "hr_party_type"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "note_maps", :force => true do |t|
    t.integer  "contact_map_id"
    t.integer  "author_user_map_id"
    t.integer  "rg_note_id"
    t.integer  "hr_note_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "ring_maps", :force => true do |t|
    t.integer  "contact_map_id"
    t.integer  "rg_ring_id"
    t.integer  "hr_ring_note_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "user_maps", :force => true do |t|
    t.integer  "account_id"
    t.integer  "hr_user_id"
    t.integer  "rg_user_id"
    t.string   "hr_user_token"
    t.boolean  "master_user",   :default => false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

end
