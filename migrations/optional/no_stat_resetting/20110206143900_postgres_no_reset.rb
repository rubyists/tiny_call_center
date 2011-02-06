Class.new Sequel::Migration do
  def up
    execute <<-SQL
CREATE OR REPLACE FUNCTION no_reset() RETURNS trigger AS $no_reset$
   BEGIN
        -- if we're an admin, let any update happen
        IF current_user = 'callcenter_admin' THEN
          RETURN NEW;
        END IF;
        -- Otherwise, Check for changes to stats, don't let any of these decrement
        IF NEW.talk_time < OLD.talk_time THEN
          NEW.talk_time := OLD.talk_time;
        END IF;
        IF NEW.calls_answered < OLD.calls_answered THEN
          NEW.calls_answered := OLD.calls_answered;
        END IF;
        RETURN NEW;
    END;
$no_reset$ LANGUAGE plpgsql;

CREATE TRIGGER no_reset BEFORE UPDATE ON agents
  FOR EACH ROW EXECUTE PROCEDURE no_reset();
    SQL
  end

  def down
    raise "Cannot go down from here"
  end
end
