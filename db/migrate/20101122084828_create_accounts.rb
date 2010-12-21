class CreateAccounts < ActiveRecord::Migration
  def self.up
    create_table :accounts do |t|
      t.integer :rg_account_id
      t.string :rg_account_id_hash
      t.string :hr_subdomain
      t.integer :rg_contacts_last_timestamp, :default => 1
      t.integer :rg_notes_last_timestamp, :default => 1
      t.integer :rg_rings_last_timestamp, :default => 1
      t.datetime :hr_parties_last_synchronized_at, :default => (Date.parse('1900-01-01')).to_time
      t.datetime :hr_notes_last_synchronized_at, :default => (Date.parse('1900-01-01')).to_time
      t.datetime :hr_ring_notes_last_synchronized_at, :default => (Date.parse('1900-01-01')).to_time      

      t.timestamps
    end
  end

  def self.down
    drop_table :accounts
  end
end
