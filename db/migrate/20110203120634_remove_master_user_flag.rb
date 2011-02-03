class RemoveMasterUserFlag < ActiveRecord::Migration
  def self.up
    remove_column :user_maps, :master_user
  end

  def self.down
    add_column :user_maps, :master_user, :boolean, :default => false
  end
end
