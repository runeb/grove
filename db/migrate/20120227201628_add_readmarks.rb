class AddReadmarks < ActiveRecord::Migration
  def self.up
    create_table :readmarks do |t|
      t.integer :location_id
      t.integer :post_id, :default => 0
      t.integer :owner
      t.integer :unread_count, :default => 0
      t.timestamps
    end
  end

  def self.down
  end
end
