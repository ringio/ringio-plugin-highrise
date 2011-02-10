# this fixes the origin and destination telephone numbers in the rings,
# they have been swapped due to a bug in the Ringio API

class FixRingNumbersSwapping < ActiveRecord::Migration
  def self.up
    Account.all.each do |a|
      # reset the last timestamp so all the rings are updated in the next synchronization
      a.rg_rings_last_timestamp = ApiOperations::Common::INITIAL_MS_DATETIME
      a.save!
    end
  end

  def self.down
  end
end
