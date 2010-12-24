class CreateAccounts < ActiveRecord::Migration
  def self.up
    create_table :accounts do |t|
      t.integer :rg_account_id
      t.string :rg_account_id_hash
      t.string :hr_subdomain
      t.integer :rg_contacts_last_timestamp, :default => ApiOperations::Common::INITIAL_MS_DATETIME
      t.integer :rg_notes_last_timestamp, :default => ApiOperations::Common::INITIAL_MS_DATETIME
      t.integer :rg_rings_last_timestamp, :default => ApiOperations::Common::INITIAL_MS_DATETIME
      t.datetime :hr_parties_last_synchronized_at, :default => ApiOperations::Common::INITIAL_DATETIME
      t.datetime :hr_notes_last_synchronized_at, :default => ApiOperations::Common::INITIAL_DATETIME
      t.datetime :hr_ring_notes_last_synchronized_at, :default => ApiOperations::Common::INITIAL_DATETIME
      t.boolean :not_synchronized_yet, :default => true

      t.timestamps
    end
  end

  def self.down
    drop_table :accounts
  end
end
