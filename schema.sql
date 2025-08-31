-- FlowLens AI-Powered DevOps Dashboard Database Schema
-- Based on PRD specifications - Simple schema for hackathon demo
-- Designed for YugabyteDB (PostgreSQL-compatible)
-- Date: August 30, 2025

-- ================================
-- Table 1: Raw GitHub Events
-- ================================

-- Raw GitHub events storage (exactly as per PRD)
CREATE TABLE raw_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type TEXT NOT NULL,          -- "pull_request", "workflow_run"
    payload JSONB NOT NULL,            -- Raw GitHub webhook payload
    processed BOOLEAN DEFAULT FALSE,   -- Flag for AI service processing
    received_at TIMESTAMPTZ DEFAULT now()
);

-- Index for efficient processing
CREATE INDEX idx_raw_events_processed ON raw_events (processed, received_at);

-- ================================
-- Table 2: AI Insights  
-- ================================

-- AI Insights linked to PRs (exactly as per PRD)
CREATE TABLE insights (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pr_number INT NOT NULL,
    commit_sha TEXT,
    author TEXT,
    avatar_url TEXT,
    risk_level TEXT,                   -- "low", "medium", "high"
    summary TEXT,                      -- One-line description from Gemini
    recommendation TEXT,               -- Suggested action from Gemini
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Index for PR lookups
CREATE INDEX idx_insights_pr ON insights (pr_number, created_at DESC);

-- ================================
-- Table 3: PR Pipeline Status
-- ================================

-- PR Pipeline status tracking (exactly as per PRD)
CREATE TABLE pipeline_runs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pr_number INT UNIQUE NOT NULL,     -- One pipeline per PR
    commit_sha TEXT,
    author TEXT,
    avatar_url TEXT,
    status_pr TEXT DEFAULT 'pending',       -- PR Created stage
    status_build TEXT DEFAULT 'pending',    -- Build Started/Completed stage  
    status_approval TEXT DEFAULT 'pending', -- Approval stage
    status_merge TEXT DEFAULT 'pending',    -- Merged stage
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Index for status queries
CREATE INDEX idx_pipeline_runs_status ON pipeline_runs (updated_at DESC);

-- ================================
-- OPTIONAL: Minimal PR Data for Flutter
-- (Can be populated from raw_events.payload)
-- ================================

-- Simplified PR table for Flutter app convenience
CREATE TABLE pull_requests_view (
    pr_number INT PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    author TEXT NOT NULL,
    author_avatar TEXT,
    commit_sha TEXT NOT NULL,
    repository_name TEXT DEFAULT 'DevOps-Malayalam/mission-control',
    branch_name TEXT,
    files_changed JSONB DEFAULT '[]'::jsonb,
    additions INT DEFAULT 0,
    deletions INT DEFAULT 0,
    is_draft BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Index for Flutter queries
CREATE INDEX idx_pr_view_updated ON pull_requests_view (updated_at DESC);

-- ================================
-- Comments for Clarity
-- ================================

COMMENT ON TABLE raw_events IS 'Stores raw GitHub webhook events for processing by AI service';
COMMENT ON TABLE insights IS 'AI-generated insights from Gemini API for each PR';
COMMENT ON TABLE pipeline_runs IS 'Tracks PR workflow status: Created → Build → Approval → Merged';
COMMENT ON TABLE pull_requests_view IS 'Simplified PR data extracted from raw_events for Flutter app';

-- ================================
-- Demo Data for Hackathon
-- ================================

-- Sample PR data for Flutter
INSERT INTO pull_requests_view (
    pr_number, title, description, author, author_avatar, commit_sha, 
    branch_name, files_changed, additions, deletions
) VALUES (
    1, 
    'Add AI insights dashboard', 
    'Implementing Gemini-powered risk assessment for pull requests',
    'dev-jitto', 
    'https://avatars.githubusercontent.com/u/dev-jitto',
    'abc123def456',
    'feature/ai-insights',
    '["lib/models/ai_insight.dart", "lib/screens/dashboard.dart"]',
    150,
    25
) ON CONFLICT (pr_number) DO NOTHING;

-- Sample insight for demo
INSERT INTO insights (pr_number, commit_sha, author, avatar_url, risk_level, summary, recommendation) 
VALUES (
    1, 
    'abc123def456', 
    'dev-jitto', 
    'https://avatars.githubusercontent.com/u/dev-jitto',
    'medium',
    'Database schema changes with new AI insights table',
    'Review carefully - schema changes require migration planning'
) ON CONFLICT DO NOTHING;

-- Sample pipeline status for demo
INSERT INTO pipeline_runs (pr_number, commit_sha, author, avatar_url, status_pr, status_build, status_approval, status_merge) 
VALUES (
    1,
    'abc123def456',
    'dev-jitto', 
    'https://avatars.githubusercontent.com/u/dev-jitto',
    'created',
    'completed',
    'pending',
    'pending'
) ON CONFLICT (pr_number) DO NOTHING;


-- ================================
-- Section 5: Real-time Notification Trigger (LISTEN/NOTIFY)
-- This is the core of our event-driven, no-polling architecture.
-- ================================

-- 1. Create a function that will be triggered on new row insertion.
CREATE OR REPLACE FUNCTION notify_new_raw_event()
RETURNS TRIGGER AS $$
BEGIN
  -- NEW.id is the UUID of the newly inserted row.
  -- We send it as the payload of the notification on the 'new_event' channel.
  PERFORM pg_notify('new_event', NEW.id::text);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2. Create a trigger that executes the function after every INSERT on raw_events.
CREATE TRIGGER raw_events_insert_trigger
AFTER INSERT ON raw_events
FOR EACH ROW
EXECUTE FUNCTION notify_new_raw_event();

COMMENT ON FUNCTION notify_new_raw_event IS 'Sends a notification on the new_event channel with the event UUID as payload.';
COMMENT ON TRIGGER raw_events_insert_trigger ON raw_events IS 'Fires after a new event is inserted to notify the API service.';