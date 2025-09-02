-- FlowLens AI-Powered DevOps Dashboard Database Schema
-- Repository-centric schema for GitHub webhook data and PRD requirements
-- Optimized for YugabyteDB (PostgreSQL-compatible)
-- Date: September 2, 2025

-- ================================
-- Table 1: Repositories (Core Entity)
-- ================================

-- Repository information from GitHub webhooks (optimized)
CREATE TABLE repositories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    github_id BIGINT UNIQUE NOT NULL,         -- GitHub repository ID (e.g., 1047607181)
    name TEXT NOT NULL,                       -- Repository name (e.g., "Test-Project")
    full_name TEXT UNIQUE NOT NULL,           -- Full name (e.g., "JittoJoseph/Test-Project")
    description TEXT,                         -- Repository description
    owner TEXT NOT NULL,                      -- Owner username (e.g., "JittoJoseph")
    is_private BOOLEAN DEFAULT FALSE,         -- Repository visibility
    default_branch TEXT DEFAULT 'main',      -- Default branch (main/master/develop)
    html_url TEXT,                           -- GitHub repository URL
    language TEXT,                           -- Primary language
    stars INT DEFAULT 0,                     -- Stargazers count
    forks INT DEFAULT 0,                     -- Forks count
    open_prs INT DEFAULT 0,                  -- Open PRs count (calculated)
    total_prs INT DEFAULT 0,                 -- Total PRs count (calculated)
    last_activity TIMESTAMPTZ,              -- Last push/activity time
    created_at TIMESTAMPTZ,                 -- Repository creation time
    updated_at TIMESTAMPTZ DEFAULT now()    -- Last webhook update
);

-- Indexes for efficient queries
CREATE INDEX idx_repositories_full_name ON repositories (full_name);
CREATE INDEX idx_repositories_owner ON repositories (owner);
CREATE INDEX idx_repositories_language ON repositories (language);
CREATE INDEX idx_repositories_updated ON repositories (updated_at DESC);
CREATE INDEX idx_repositories_activity ON repositories (last_activity DESC);

-- ================================
-- Table 2: AI Insights (Updated with repo_id)
-- ================================

-- AI Insights linked to PRs (exactly as per PRD)
CREATE TABLE insights (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    repo_id UUID NOT NULL REFERENCES repositories(id) ON DELETE CASCADE,
    pr_number INT NOT NULL,
    commit_sha TEXT,
    author TEXT,
    avatar_url TEXT,
    risk_level TEXT CHECK (risk_level IN ('low', 'medium', 'high')),
    summary TEXT,                      -- One-line description from Gemini
    recommendation TEXT,               -- Suggested action from Gemini
    processed BOOLEAN DEFAULT FALSE,   -- Flag for polling system
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Index for PR lookups
CREATE INDEX idx_insights_repo_pr ON insights (repo_id, pr_number, created_at DESC);
CREATE INDEX idx_insights_pr ON insights (pr_number, created_at DESC);
CREATE INDEX idx_insights_processed ON insights (processed, created_at DESC) WHERE processed = FALSE;

-- ================================
-- Table 3: PR Pipeline Status (Updated with repo_id)
-- ================================

-- PR Pipeline status tracking (streamlined)
CREATE TABLE pipeline_runs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    repo_id UUID NOT NULL REFERENCES repositories(id) ON DELETE CASCADE,
    pr_number INT NOT NULL,                  -- PR number (unique per repository)
    commit_sha TEXT,
    author TEXT,
    avatar_url TEXT,
    title TEXT,                        -- PR title
    status_pr TEXT DEFAULT 'pending',       -- PR Created stage
    status_build TEXT DEFAULT 'pending',    -- Build Started/Completed stage
    status_approval TEXT DEFAULT 'pending', -- Approval stage
    status_merge TEXT DEFAULT 'pending',    -- Merged stage
    history JSONB DEFAULT '[]'::jsonb,      -- Timeline of status changes (small audit trail)
    processed BOOLEAN DEFAULT FALSE,        -- Flag for polling system
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (repo_id, pr_number)             -- One pipeline per PR per repository
);

-- Index for status queries
CREATE INDEX idx_pipeline_runs_status ON pipeline_runs (updated_at DESC);
CREATE INDEX idx_pipeline_runs_repo_pr ON pipeline_runs (repo_id, pr_number);
CREATE INDEX idx_pipeline_runs_processed ON pipeline_runs (processed, updated_at DESC) WHERE processed = FALSE;

-- ================================
-- Table 4: Pull Requests (Updated with repo_id)
-- ================================

-- Essential PR data for Flutter app (only what we need)
-- Handles multiple events for same PR via UPSERT (ON CONFLICT repo_id, pr_number)
-- Each event (opened, approved, closed, etc.) updates the same record
CREATE TABLE pull_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    repo_id UUID NOT NULL REFERENCES repositories(id) ON DELETE CASCADE,
    pr_number INT NOT NULL,
    title TEXT NOT NULL,
    description TEXT,                                    -- PR body/description from GitHub
    author TEXT NOT NULL,
    author_avatar TEXT,
    commit_sha TEXT NOT NULL,
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
    merged BOOLEAN DEFAULT FALSE,                        -- Whether PR was merged
    merged_at TIMESTAMPTZ,                              -- When PR was merged
    closed_at TIMESTAMPTZ,                              -- When PR was closed
    history JSONB DEFAULT '[]'::jsonb,                   -- Timeline of PR-level changes (audit trail)
    processed BOOLEAN DEFAULT FALSE,                     -- Flag for polling system
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (repo_id, pr_number)                         -- One PR per number per repository
);

-- Index for Flutter queries
CREATE INDEX idx_pr_updated ON pull_requests (updated_at DESC);
CREATE INDEX idx_pr_repo_state ON pull_requests (repo_id, state);
CREATE INDEX idx_pr_author ON pull_requests (author);
CREATE INDEX idx_pr_processed ON pull_requests (processed, updated_at DESC) WHERE processed = FALSE;

-- ================================
-- Comments for Clarity
-- ================================

COMMENT ON TABLE repositories IS 'GitHub repositories tracked by the system with metadata from webhooks';
COMMENT ON TABLE insights IS 'AI-generated insights from Gemini API for each PR';
COMMENT ON TABLE pipeline_runs IS 'Tracks PR workflow status: Created → Build → Approval → Merged';
COMMENT ON TABLE pull_requests IS 'Essential PR data for Flutter app with repository relationship';

COMMENT ON COLUMN insights.processed IS 'Flag to track if this insight has been processed by the API service polling system';
COMMENT ON COLUMN pipeline_runs.processed IS 'Flag to track if this pipeline run has been processed by the API service polling system';
COMMENT ON COLUMN pull_requests.processed IS 'Flag to track if this PR has been processed by the API service polling system';
