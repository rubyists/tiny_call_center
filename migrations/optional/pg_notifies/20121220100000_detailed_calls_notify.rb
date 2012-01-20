Class.new Sequel::Migration do
  def up
    execute <<-SQL
      CREATE OR REPLACE FUNCTION channel_notifications() RETURNS TRIGGER AS $detailed_calls$
      BEGIN
        --
        -- Send NOTIFY events for every change to the detailed_calls view
        --
        IF (TG_OP = 'INSERT') THEN
            PERFORM pg_notify('channel_insert', row_to_json_object(NEW));
            RETURN NEW;
        ELSIF (TG_OP = 'UPDATE') THEN
            IF OLD.callstate <> NEW.callstate THEN
              PERFORM pg_notify('channel_update', row_to_json_object(NEW));
              RETURN NEW;
            END IF;
        ELSIF (TG_OP = 'DELETE') THEN
            PERFORM pg_notify('channel_delete', '{"uuid": "'||OLD.uuid||'", "callstate": "'||OLD.callstate||'"}');
            RETURN OLD;
        END IF;
        RETURN NULL; -- result is ignored since this is an AFTER trigger
      END;
      $detailed_calls$ LANGUAGE plpgsql;
    SQL
    execute <<-SQL
      CREATE TRIGGER channel_insert
        AFTER INSERT ON channels
        FOR EACH ROW
        EXECUTE PROCEDURE channel_notifications();
      CREATE TRIGGER channel_update
        AFTER UPDATE ON channels
        FOR EACH ROW
        EXECUTE PROCEDURE channel_notifications();
      CREATE TRIGGER channel_delete
        BEFORE DELETE ON channels
        FOR EACH ROW
        EXECUTE PROCEDURE channel_notifications();
    SQL
  end

  def down
    execute 'DROP TRIGGER "channel_insert" on channels;'
    execute 'DROP TRIGGER "channel_update" on channels;'
    execute 'DROP TRIGGER "channel_delete" on channels;'
    execute 'DROP FUNCTION channel_notifications();'
  end
end
