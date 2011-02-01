Class.new Sequel::Migration do
  def up
    add_column :call_records, :agent, String
  end

  def down
    drop_column :call_records, :agent
  end
end
