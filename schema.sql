-- FlowLens AI-Powered DevOps Dashboard Database Schema
-- Streamlined for actual GitHub webhook data and PRD requirements
-- Optimized for YugabyteDB (PostgreSQL-compatible)
-- Date: August 31, 2025

-- ================================
-- Table 1: Raw GitHub Events (Simplified)
-- ================================

-- Raw GitHub events storage (kept minimal for debugging)
CREATE TABLE raw_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type TEXT NOT NULL,          -- "pull_request", "workflow_run", "push"
    delivery_id TEXT UNIQUE,           -- GitHub delivery ID for deduplication
    payload JSONB NOT NULL,            -- Raw GitHub webhook payload
    processed BOOLEAN DEFAULT FALSE,   -- Flag for AI service processing
    received_at TIMESTAMPTZ DEFAULT now()
);

-- Index for efficient processing
CREATE INDEX idx_raw_events_processed ON raw_events (processed, received_at);
CREATE INDEX idx_raw_events_delivery ON raw_events (delivery_id);

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
    risk_level TEXT CHECK (risk_level IN ('low', 'medium', 'high')),
    summary TEXT,                      -- One-line description from Gemini
    recommendation TEXT,               -- Suggested action from Gemini
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Index for PR lookups
CREATE INDEX idx_insights_pr ON insights (pr_number, created_at DESC);

-- ================================
-- Table 3: PR Pipeline Status
-- ================================

-- PR Pipeline status tracking (streamlined)
CREATE TABLE pipeline_runs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pr_number INT UNIQUE NOT NULL,     -- One pipeline per PR
    commit_sha TEXT,
    author TEXT,
    avatar_url TEXT,
    title TEXT,                        -- PR title
    status_pr TEXT DEFAULT 'pending',       -- PR Created stage
    status_build TEXT DEFAULT 'pending',    -- Build Started/Completed stage
    status_approval TEXT DEFAULT 'pending', -- Approval stage
    status_merge TEXT DEFAULT 'pending',    -- Merged stage
    history JSONB DEFAULT '[]'::jsonb,      -- Timeline of status changes (small audit trail)
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Index for status queries
CREATE INDEX idx_pipeline_runs_status ON pipeline_runs (updated_at DESC);
CREATE INDEX idx_pipeline_runs_pr ON pipeline_runs (pr_number);

-- ================================
-- Table 4: Pull Requests (Simplified)
-- ================================

-- Essential PR data for Flutter app (only what we need)
-- Handles multiple events for same PR via UPSERT (ON CONFLICT pr_number)
-- Each event (opened, approved, closed, etc.) updates the same record
CREATE TABLE pull_requests (
    pr_number INT PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,                                    -- PR body/description from GitHub
    author TEXT NOT NULL,
    author_avatar TEXT,
    commit_sha TEXT NOT NULL,
    repository_name TEXT DEFAULT 'DevOps-Malayalam/mission-control',
    branch_name TEXT,
    base_branch TEXT DEFAULT 'master',                    -- Target branch (master/main/develop)
    pr_url TEXT,                                         -- GitHub PR URL for easy access
    commit_urls JSONB DEFAULT '[]'::jsonb,               -- Array of commit URLs
    files_changed JSONB DEFAULT '[]'::jsonb,             -- Array of changed file details with diffs
    additions INT DEFAULT 0,
    deletions INT DEFAULT 0,
    changed_files INT DEFAULT 0,                         -- Number of files changed
    commits_count INT DEFAULT 0,                         -- Number of commits in PR
    labels JSONB DEFAULT '[]'::jsonb,                    -- PR labels for categorization
    assignees JSONB DEFAULT '[]'::jsonb,                 -- Assigned users
    reviewers JSONB DEFAULT '[]'::jsonb,                 -- Requested reviewers
    is_draft BOOLEAN DEFAULT FALSE,
    state TEXT DEFAULT 'open',                           -- open, closed, merged
    history JSONB DEFAULT '[]'::jsonb,                   -- Timeline of PR-level changes (audit trail)
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Index for Flutter queries
CREATE INDEX idx_pr_updated ON pull_requests (updated_at DESC);
CREATE INDEX idx_pr_author ON pull_requests (author);

-- ================================
-- Comments for Clarity
-- ================================

COMMENT ON TABLE raw_events IS 'Stores raw GitHub webhook events for processing and debugging';
COMMENT ON TABLE insights IS 'AI-generated insights from Gemini API for each PR';
COMMENT ON TABLE pipeline_runs IS 'Tracks PR workflow status: Created → Build → Approval → Merged';
COMMENT ON TABLE pull_requests IS 'Essential PR data for Flutter app with commit URLs';
