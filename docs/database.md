# FlowLens Database Guide

This document provides a comprehensive guide to setting up and understanding the YugabyteDB schema used by FlowLens.

## 1. Database Setup

FlowLens uses YugabyteDB, a high-performance, distributed SQL database that is PostgreSQL-compatible.

### Prerequisites
- A [YugabyteDB Cloud](https://cloud.yugabyte.com/) account (a free sandbox cluster is sufficient).
- A PostgreSQL client like `psql` to run the schema script.

### Setup Steps
1.  **Create a Cluster**: In the YugabyteDB Cloud dashboard, create a new "Sandbox" cluster.
2.  **Get Connection String**: Once the cluster is ready, click "Connect" and copy the `psql` connection string. It will look like this:
    ```
    postgresql://admin:password@your-host.aws.ybdb.io:5433/yugabyte?ssl=true
    ```
3.  **Apply Schema**: Connect to your database using the connection string and execute the SQL script below to create the necessary tables and indexes.

---

## 2. Database Schema (v2.0)

This is the repository-centric schema for FlowLens v2.0.

```sql
-- Master table for repositories
CREATE TABLE repositories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    github_id BIGINT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    full_name TEXT UNIQUE NOT NULL,
    owner TEXT NOT NULL,
    owner_avatar_url TEXT,
    is_private BOOLEAN,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Pull request data, linked to a repository
CREATE TABLE pull_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    repo_id UUID NOT NULL REFERENCES repositories(id) ON DELETE CASCADE,
    pr_number INT NOT NULL,
    title TEXT NOT NULL,
    author TEXT,
    author_avatar TEXT,
    commit_sha TEXT,
    branch_name TEXT,
    state TEXT, -- 'open', 'closed', 'merged'
    files_changed JSONB, -- Stores the raw 'files_changed' array from webhooks for AI processing
    additions INT,
    deletions INT,
    processed BOOLEAN DEFAULT FALSE, -- Flag for API service polling
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (repo_id, pr_number)
);

-- Pipeline status tracking, linked to a pull request
CREATE TABLE pipeline_runs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    repo_id UUID NOT NULL REFERENCES repositories(id) ON DELETE CASCADE,
    pr_number INT NOT NULL,
    commit_sha TEXT,
    status_pr TEXT DEFAULT 'pending',
    status_build TEXT DEFAULT 'pending',
    status_approval TEXT DEFAULT 'pending',
    status_merge TEXT DEFAULT 'pending',
    processed BOOLEAN DEFAULT FALSE, -- Flag for API service polling
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (repo_id, pr_number)
);

-- AI-generated insights, linked to a pull request
CREATE TABLE insights (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    repo_id UUID NOT NULL REFERENCES repositories(id) ON DELETE CASCADE,
    pr_number INT NOT NULL,
    commit_sha TEXT,
    risk_level TEXT, -- 'low', 'medium', 'high'
    summary TEXT,
    recommendation TEXT,
    processed BOOLEAN DEFAULT FALSE, -- Flag for API service polling
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes for performance
CREATE INDEX idx_pull_requests_processed ON pull_requests(processed);
CREATE INDEX idx_pipeline_runs_processed ON pipeline_runs(processed);
CREATE INDEX idx_insights_processed ON insights(processed);
```

---

## 3. Field-Level Documentation

### Table: `repositories`
- `id` (UUID PK): The internal unique ID for the repository.
- `github_id` (BIGINT UNIQUE): The numerical ID of the repository from GitHub.
- `name` (TEXT): The name of the repository (e.g., `mission-control`).
- `full_name` (TEXT UNIQUE): The full name including the owner (e.g., `DevOps-Malayalam/mission-control`).
- `owner` (TEXT): The GitHub login of the repository owner.
- `owner_avatar_url` (TEXT): URL for the owner's avatar.
- `is_private` (BOOLEAN): Flag indicating if the repository is private.
- `description` (TEXT): The repository's description.
- `created_at` / `updated_at` (TIMESTAMPTZ): Record timestamps.

### Table: `pull_requests`
- `id` (UUID PK): Unique ID for the pull request record.
- `repo_id` (UUID FK): Links to the `repositories` table.
- `pr_number` (INT): The pull request number, unique per repository.
- `title` (TEXT): The title of the PR.
- `author` / `author_avatar` (TEXT): The author's GitHub login and avatar URL.
- `commit_sha` (TEXT): The SHA of the head commit.
- `branch_name` (TEXT): The name of the source branch.
- `state` (TEXT): The current state (`open`, `closed`, `merged`).
- `files_changed` (JSONB): The raw JSON array from GitHub detailing file changes, including patches, for AI analysis.
- `additions` / `deletions` (INT): Line change statistics.
- `processed` (BOOLEAN): Polling flag. Set to `FALSE` on insert/update for the API service to process.

### Table: `pipeline_runs`
- `id` (UUID PK): Unique ID for the pipeline run record.
- `repo_id` (UUID FK): Links to the `repositories` table.
- `pr_number` (INT): The associated pull request number.
- `commit_sha` (TEXT): The commit SHA that triggered this pipeline state.
- `status_pr` / `status_build` / `status_approval` / `status_merge` (TEXT): The status of each stage in the workflow (e.g., `pending`, `running`, `passed`, `failed`, `merged`).
- `processed` (BOOLEAN): Polling flag.

### Table: `insights`
- `id` (UUID PK): Unique ID for the insight record.
- `repo_id` (UUID FK): Links to the `repositories` table.
- `pr_number` (INT): The associated pull request number.
- `commit_sha` (TEXT): The commit SHA this insight was generated for.
- `risk_level` (TEXT): AI-assessed risk (`low`, `medium`, `high`).
- `summary` (TEXT): A one-line summary generated by the AI.
- `recommendation` (TEXT): A suggested action or review focus from the AI.
- `processed` (BOOLEAN): Polling flag.

</br>

> ‎ 
> **</> Built by Mission Control | DevByZero 2025**
>
> *Defining the infinite possibilities in your DevOps pipeline.*
> ‎ 
