-- ================================
-- Real-time Notification Triggers for FlowLens Schema
-- ================================

-- Function to notify when new pull requests are created or updated
CREATE OR REPLACE FUNCTION notify_pr_event() RETURNS TRIGGER AS $$
BEGIN
    -- Send notification with just the PR ID - API service will query for details
    PERFORM pg_notify('pr_event', NEW.id::text);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to notify when pipeline status changes
CREATE OR REPLACE FUNCTION notify_pipeline_event() RETURNS TRIGGER AS $$
BEGIN
    -- Send notification with just the pipeline run ID - API service will query for details
    PERFORM pg_notify('pipeline_event', NEW.id::text);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to notify when insights are generated
CREATE OR REPLACE FUNCTION notify_insight_event() RETURNS TRIGGER AS $$
BEGIN
    -- Send notification with just the insight ID - API service will query for details
    PERFORM pg_notify('insight_event', NEW.id::text);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing triggers to ensure clean state
DROP TRIGGER IF EXISTS trg_pull_requests_notify ON pull_requests;
DROP TRIGGER IF EXISTS trg_pipeline_runs_notify ON pipeline_runs;
DROP TRIGGER IF EXISTS trg_insights_notify ON insights;

-- Create triggers for pull requests (INSERT and UPDATE)
CREATE TRIGGER trg_pull_requests_notify
    AFTER INSERT OR UPDATE ON pull_requests
    FOR EACH ROW
    EXECUTE FUNCTION notify_pr_event();

-- Create triggers for pipeline runs (INSERT and UPDATE)
CREATE TRIGGER trg_pipeline_runs_notify
    AFTER INSERT OR UPDATE ON pipeline_runs
    FOR EACH ROW
    EXECUTE FUNCTION notify_pipeline_event();

-- Create trigger for insights (INSERT only, since insights are immutable)
CREATE TRIGGER trg_insights_notify
    AFTER INSERT ON insights
    FOR EACH ROW
    EXECUTE FUNCTION notify_insight_event();

-- Comments for documentation
COMMENT ON FUNCTION notify_pr_event IS 'Sends pg_notify signal with PR UUID when pull requests are created or updated';
COMMENT ON FUNCTION notify_pipeline_event IS 'Sends pg_notify signal with pipeline run UUID when status changes';
COMMENT ON FUNCTION notify_insight_event IS 'Sends pg_notify signal with insight UUID when new insights are generated';

COMMENT ON TRIGGER trg_pull_requests_notify ON pull_requests IS 'Notifies API service of PR changes with UUID';
COMMENT ON TRIGGER trg_pipeline_runs_notify ON pipeline_runs IS 'Notifies API service of pipeline status changes with UUID';
COMMENT ON TRIGGER trg_insights_notify ON insights IS 'Notifies API service of new insights with UUID';
