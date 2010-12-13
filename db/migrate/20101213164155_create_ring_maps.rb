class CreateRingMaps < ActiveRecord::Migration
  def self.up
    create_table :ring_maps do |t|
      t.integer :contact_map_id
      t.integer :rg_ring_id
      t.integer :hr_note_id

      t.timestamps
    end
  end

  def self.down
    drop_table :ring_maps
  end
end
