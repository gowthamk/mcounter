class CreateMCounters < ActiveRecord::Migration
  def change
    create_table :m_counters do |t|
      t.integer :count

      t.timestamps
    end
  end
end
