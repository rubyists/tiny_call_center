Class.new Sequel::Migration do
  def up
    add_column :manager, :admin, FalseClass
  end

  def down
    drop_column :manager, :admin
  end
end
