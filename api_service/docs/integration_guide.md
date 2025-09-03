# API Service Integration Guide

This guide provides essential information for developers of other services (like the Ingestion Service) and frontend applications that interact with the FlowLens API Service.

## For Ingestion Service Developers

The Ingestion Service and API Service are decoupled via the database. To ensure the API Service's poller can correctly detect and process changes, the Ingestion Service **must** adhere to the following critical requirements.

### ⚠️ Critical Requirement: Set `processed = FALSE`

When inserting a new record or updating ANY existing record in the `pull_requests`, `pipeline_runs`, or `insights` tables, you **MUST** explicitly set the `processed` column to `FALSE`.

This flag is the primary trigger for the API Service's processing loop. Failure to set this flag will result in the change being ignored by the AI and WebSocket broadcasting systems.

**Example SQL for Updating a PR:**
```sql
-- When a PR is merged, the Ingestion Service should run this update:
UPDATE pull_requests
SET
  state = 'merged',
  processed = FALSE, -- This is crucial!
  updated_at = now()
WHERE repo_id = $1 AND pr_number = $2;
```

### Other Requirements

1.  **Repository Management:** Before creating a `pull_requests` record, ensure the corresponding repository exists in the `repositories` table. If not, create it first.
2.  **Foreign Key Linking:** All new records in `pull_requests`, `pipeline_runs`, and `insights` must contain the correct `repo_id` UUID that links back to the `repositories` table.
3.  **Persist `files_changed` Data:** For `pull_request` events, the complete `files_changed` JSON array from the GitHub webhook payload must be stored in the `files_changed` column. This data is essential for the AI analysis.

## For Frontend Developers

1.  **Adopt a Multi-Repository Mindset:**
    - Begin by fetching the list of available repositories from `GET /api/repositories`.
    - Allow the user to select a repository.
    - Use the selected `repository_id` as a query parameter in all subsequent API calls.

2.  **Use WebSockets for Real-Time Triggers, Not State:**
    - The WebSocket sends minimal update notifications. Use these messages as a signal to refresh data for a specific PR.
    - Do not rely on the WebSocket to transmit the full application state. Fetch the latest state via the REST APIs after receiving a notification. See the **[WebSocket Guide](./websockets.md)** for details.

3.  **Leverage Enhanced Data:** The v2.0 APIs provide richer data than before. Your application can now access and display detailed file change information and more nuanced AI insights.


</br>

> ‎ 
> **</> Built by Mission Control | DevByZero 2025**
>
> *Defining the infinite possibilities in your DevOps pipeline.*
> ‎ 
