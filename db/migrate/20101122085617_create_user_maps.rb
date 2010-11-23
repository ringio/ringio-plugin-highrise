class CreateUserMaps < ActiveRecord::Migration
  def self.up
    create_table :user_maps do |t|
      t.integer :account_id
      t.integer :hr_user_id
      t.integer :rg_user_id
      t.string :hr_user_token
      t.string :rg_email
      t.boolean :master_user, :default => false

      t.timestamps
    end
  end

  def self.down
    drop_table :user_maps
  end
end
