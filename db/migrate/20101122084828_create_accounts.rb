class CreateAccounts < ActiveRecord::Migration
  def self.up
    create_table :accounts do |t|
      t.integer :rg_account_id
      t.string :hr_subdomain
      t.boolean :sync_only_new_data, :default => true

      t.timestamps
    end
  end

  def self.down
    drop_table :accounts
  end
end
