Class.new Sequel::Migration do
  def up
    execute <<-SQL
      CREATE OR REPLACE FUNCTION call_notifications() RETURNS TRIGGER AS $detailed_calls$
      BEGIN
        --
        -- Send NOTIFY events for every change to the calls table
        --
        IF (TG_OP = 'INSERT') THEN
            PERFORM pg_notify('call_insert', '{"uuid": "'||NEW.uuid||'", "callstate": "'||NEW.callstate||'"}');
            RETURN NEW;
        ELSIF (TG_OP = 'UPDATE') THEN
            IF OLD.callstate <> NEW.callstate THEN
              PERFORM pg_notify('call_update', '{"uuid": "'||NEW.uuid||'", "callstate": "'||NEW.callstate||'"}');
              RETURN NEW;
            END IF;
        ELSIF (TG_OP = 'DELETE') THEN
            PERFORM pg_notify('call_delete', '{"uuid": "'||OLD.uuid||'", "callstate": "'||OLD.callstate||'"}');
            RETURN OLD;
        END IF;
        RETURN NULL; -- result is ignored since this is an AFTER trigger
      END;
      $detailed_calls$ LANGUAGE plpgsql;
    SQL
    execute <<-SQL
      CREATE TRIGGER call_insert
        AFTER INSERT ON calls
        FOR EACH ROW
        EXECUTE PROCEDURE call_notifications();
      CREATE TRIGGER call_update
        AFTER UPDATE ON calls
        FOR EACH ROW
        EXECUTE PROCEDURE call_notifications();
      CREATE TRIGGER call_delete
        BEFORE DELETE ON calls
        FOR EACH ROW
        EXECUTE PROCEDURE call_notifications();
    SQL
  end

  def down
    execute 'DROP TRIGGER "call_insert" on calls;'
    execute 'DROP TRIGGER "call_update" on calls;'
    execute 'DROP TRIGGER "call_delete" on calls;'
    execute 'DROP FUNCTION call_notifications();'
  end
end
