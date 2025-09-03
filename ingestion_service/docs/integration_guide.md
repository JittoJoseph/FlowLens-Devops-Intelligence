# Ingestion Service Integration Guide

This guide outlines the core responsibilities and data contracts for the FlowLens Ingestion Service. Adhering to these patterns is crucial for the correct functioning of the entire FlowLens system.

## Core Responsibilities

The Ingestion Service has a focused set of responsibilities:
1.  **Receive**: Accept incoming webhook events from GitHub at the `/webhook` endpoint.
2.  **Verify**: Authenticate the webhook using the HMAC-SHA256 signature and the shared secret.
3.  **Persist**: Write the event data to the appropriate tables in the YugabyteDB database.
4.  **Flag for Processing**: Mark new or updated records so the downstream API Service can process them.

The service **should not** contain any complex business logic, AI processing, or client-facing API endpoints. Its sole purpose is to act as a secure and reliable data gateway.

## Data Persistence Contract

When processing a GitHub webhook, the service must perform the following database operations.

### 1. Manage Repositories
- Upon receiving an event, parse the repository information.
- Use an `UPSERT` (or `INSERT ... ON CONFLICT`) operation to create or update the record in the `repositories` table. This ensures repository data is always up-to-date.
- Retrieve the `id` (UUID) of the repository record for use in subsequent operations.

### 2. Manage Pull Requests and Pipelines
- For events related to a pull request, use `UPSERT` to create or update records in the `pull_requests` and `pipeline_runs` tables.
- **Crucially**, link these records to the parent repository using the `repo_id` obtained in the previous step.
- Populate all relevant fields from the webhook payload (e.g., `title`, `author`, `state`, pipeline statuses).

### 3. Store `files_changed` Data
- For `pull_request` events, extract the `files_changed` JSON array from the webhook payload.
- Store this entire JSON object directly into the `files_changed` column of the `pull_requests` table. This data is vital for the API Service's AI analysis.

### 4. ⚠️ Set the `processed` Flag
- This is the most critical part of the integration contract.
- For every `INSERT` or `UPDATE` to the `pull_requests`, `pipeline_runs`, or `insights` tables, the `processed` column **MUST** be set to `FALSE`.
- This flag signals to the API Service's database poller that the record is new or has been updated and requires processing.

**Example `UPSERT` Logic for a Pipeline Update:**
```sql
INSERT INTO pipeline_runs (repo_id, pr_number, status_build, processed)
VALUES ($1, $2, 'passed', FALSE)
ON CONFLICT (repo_id, pr_number)
DO UPDATE SET
  status_build = EXCLUDED.status_build,
  processed = FALSE, -- Must be set in the UPDATE clause as well!
  updated_at = now();
```