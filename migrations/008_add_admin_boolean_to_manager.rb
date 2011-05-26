Class.new Sequel::Migration do
  def up
    add_column :managers, :admin, FalseClass
  end

  def down
    drop_column :managers, :admin
  end
end
