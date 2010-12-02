class CreateUserMaps < ActiveRecord::Migration
  def self.up
    create_table :user_maps do |t|
      t.integer :account_id
      t.integer :hr_user_id
      t.integer :rg_user_id
      t.string :hr_user_token
      t.boolean :master_user, :default => false
      t.integer :rg_last_timestamp, :default => 0
      t.datetime :hr_last_synchronized_at, :default => (Date.parse('1900-01-01')).to_time

      t.timestamps
    end
  end

  def self.down
    drop_table :user_maps
  end
end
