class CreateContactMaps < ActiveRecord::Migration
  def self.up
    create_table :contact_maps do |t|
      t.integer :user_map_id
      t.integer :rg_contact_id
      t.integer :hr_party_id
      t.string :hr_party_type
      t.integer :rg_last_timestamp, :default => 0
      t.datetime :hr_last_synchronized_at, :default => (Date.parse('1900-01-01')).to_time

      t.timestamps
    end
  end

  def self.down
    drop_table :contact_maps
  end
end
