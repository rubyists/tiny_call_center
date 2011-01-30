Class.new Sequel::Migration do
  def up
    add_column :managers, :eavesdrop_extension, String
  end
  
  def down
    drop_column :managers, :eavesdrop_extension
  end
end
