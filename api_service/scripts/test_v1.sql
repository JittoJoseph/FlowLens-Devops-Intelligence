-- ====================================================================
-- TEST SCRIPT: Simulate "PR #101 Opened" for FlowLens api_service
-- ====================================================================
-- This script prepares the database to test the api_service in isolation,
-- mimicking the state created by the ingestion_service upon receiving
-- a 'pull_request' webhook with an 'opened' action.
--
-- After running this, starting the api_service should:
-- 1. Detect the unprocessed event in `raw_events`.
-- 2. Call the Gemini AI to generate insights.
-- 3. Insert a new record into the `insights` table for PR #101.
-- 4. Mark the raw_event as 'processed = true'.
-- 5. Broadcast the new PR state via WebSocket.
-- ====================================================================

-- ---
-- Part 1: Clean up previous test runs for PR #101 to ensure idempotency
-- ---
BEGIN;
  DELETE FROM raw_events WHERE payload->'pull_request'->>'number' = '101';
  DELETE FROM insights WHERE pr_number = 101;
  DELETE FROM pipeline_runs WHERE pr_number = 101;
  DELETE FROM pull_requests WHERE pr_number = 101;
COMMIT;

-- ---
-- Part 2: Simulate the ingestion_service creating the core PR records
-- ---

-- Step 2a: Create the main record in the `pull_requests` table.
-- This is the data the AI service will use for its analysis.
INSERT INTO pull_requests (
  pr_number,
  title,
  description,
  author,
  author_avatar,
  commit_sha,
  repository_name,
  branch_name,
  base_branch,
  pr_url,
  additions,
  deletions,
  changed_files,
  is_draft,
  state,
  created_at,
  updated_at
) VALUES (
  101,
  'feat: Implement user profile page',
  'This PR introduces a new user profile page where users can view and edit their information.\n\n- Adds a new route `/profile`.\n- Creates `ProfileComponent`.\n- Includes basic form validation.',
  'test-developer',
  'https://avatars.githubusercontent.com/u/123456?v=4',
  'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8g9h0',
  'DevByZero/FlowLens-Demo',
  'feat/user-profile',
  'main',
  'https://github.com/DevByZero/FlowLens-Demo/pull/101',
  150,
  25,
  5,
  false,
  'open',
  NOW(),
  NOW()
);

-- Step 2b: Create the initial record in the `pipeline_runs` table.
-- The status is 'opened', and all other stages are 'pending'.
INSERT INTO pipeline_runs (
  pr_number,
  commit_sha,
  author,
  avatar_url,
  title,
  status_pr,
  status_build,
  status_approval,
  status_merge,
  created_at,
  updated_at
) VALUES (
  101,
  'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8g9h0',
  'test-developer',
  'https://avatars.githubusercontent.com/u/123456?v=4',
  'feat: Implement user profile page',
  'opened',    -- Initial state
  'pending',   -- Waiting for CI
  'pending',   -- Waiting for review
  'pending',   -- Not merged yet
  NOW(),
  NOW()
);

-- ---
-- Part 3: Create the TRIGGER event in `raw_events`.
-- THIS IS THE MOST IMPORTANT STEP FOR THE API_SERVICE.
-- ---
INSERT INTO raw_events (
  event_type,
  delivery_id,
  payload,
  processed  -- Must be FALSE to trigger the poller
) VALUES (
  'pull_request',
  gen_random_uuid(),
  '{
    "action": "opened",
    "number": 101,
    "pull_request": {
