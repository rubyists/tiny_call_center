Class.new Sequel::Migration do
  def up
    add_column :call_records, :left_cid_num, String
    add_column :call_records, :left_cid_name, String
    add_column :call_records, :left_destination, String
    add_column :call_records, :left_channel, String
    add_column :call_records, :left_uuid, String
    add_column :call_records, :right_cid_num, String
    add_column :call_records, :right_cid_name, String
    add_column :call_records, :right_destination, String
    add_column :call_records, :right_channel, String
    add_column :call_records, :right_uuid, String
    drop_column :call_records, :caller_id_number
    drop_column :call_records, :caller_id_name
    drop_column :call_records, :channel
    drop_column :call_records, :destination_number
    drop_column :call_records, :uuid
  end

  def down
    raise "Cannot go down from here"
  end
end
