-- ================================
-- Real-time Notification Trigger
-- ================================

-- 1. Create the function that will be triggered
CREATE OR REPLACE FUNCTION notify_new_event() RETURNS TRIGGER AS $$
BEGIN
    -- Send a notification on the 'new_event' channel.
    -- The payload is the UUID of the newly inserted row, cast to TEXT.
    PERFORM pg_notify('new_event', NEW.id::text);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2. Create the trigger to execute the function after each INSERT on raw_events
-- We use a "FOR EACH ROW" trigger to get access to the NEW record.
-- Drop the trigger first to ensure idempotency on re-runs.
DROP TRIGGER IF EXISTS trg_raw_events_insert ON raw_events;
CREATE TRIGGER trg_raw_events_insert
    AFTER INSERT ON raw_events
    FOR EACH ROW
    EXECUTE FUNCTION notify_new_event();

COMMENT ON FUNCTION notify_new_event IS 'Sends a pg_notify signal with the new event ID when a row is inserted into raw_events.';
COMMENT ON TRIGGER trg_raw_events_insert ON raw_events IS 'Executes the notify_new_event function after a new event is inserted.';