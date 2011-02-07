class AddRingioHiddenContactFlag < ActiveRecord::Migration
  def self.up
    add_column :contact_maps, :rg_hidden, :boolean, :default => false
  end

  def self.down
    remove_column :contact_maps, :rg_hidden
  end
end
