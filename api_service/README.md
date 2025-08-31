# FlowLens API Service

## 1. Overview

The FlowLens API Service is the central data hub and intelligence layer for the entire FlowLens platform. Written in Python using the FastAPI framework, its core responsibilities are:

*   **Data Enrichment:** It polls the database for new, unprocessed GitHub events and enriches them with AI-powered insights using the Gemini API.
*   **Data Serving:** It provides a set of clean, aggregated REST endpoints for the Flutter application to fetch its initial state.
*   **Real-time Notifications:** It pushes live updates to all connected clients via WebSockets whenever the state of a pull request changes.

This service acts as the "brain" of the operation, transforming raw event data into actionable intelligence and ensuring the frontend is always up-to-date.

---

## 2. Architecture & Data Flow

The API service operates on a **resilient polling mechanism**, decoupling it from the `ingestion-service`. The database (YugabyteDB) serves as the message queue between the two services.

```
+-------------------+      (Webhook)       +---------------------+
|      GitHub       | -------------------> | Ingestion Service   |
+-------------------+                      |      (Node.js)      |
                                           +----------+----------+
                                                      | (Writes to DB)
                                                      v
+-----------------------------------------------------+------------------------------------------------------+
|                                         Database (YugabyteDB)                                              |
|                                                                                                            |
| +------------------+   +--------------------+   +-----------------+   +----------------------------------+ |
| |  raw_events      |   | pull_requests_view |   | pipeline_runs   |   | insights                         | |
| | (processed=false)|   | (PR metadata)      |   | (CI/CD status)  |   | (AI-generated)                   | |
| +-------^----------+   +--------------------+   +-----------------+   +----------------^-----------------+ |
+---------|------------------------------------------------------------------------------|-------------------+
          | (Polls every 2s)                                                             | (Writes to DB)
          v                                                                              |
+---------+------------------------------------------------------------------------------+---------+
|                                        FlowLens API Service (Python)                               |
|                                                                                                    |
|  +---------------------+        +-----------------------+        +-------------------------------+ |
|  | Event Poller        | -----> | AI Enrichment (Gemini)| -----> |   Data Aggregation & Serving  | |
|  | (Checks raw_events) |        | (Generates insights)  |        | (REST API & WebSocket Manager)| |
|  +---------------------+        +-----------------------+        +-------------------------------+ |
+--------------------------------------------+-------------------------------------------------------+
                                             | (REST API for initial load)
                                             | (WebSocket for live updates)
                                             v
                                     +-------+-------+
                                     | Flutter App   |
                                     +---------------+
```

**The flow is as follows:**
1.  The **Ingestion Service** receives a webhook, performs initial data extraction into `pull_requests_view` and `pipeline_runs`, and critically, inserts a record into `raw_events` with `processed = false`.
2.  The **API Service** runs a background poller that queries the `raw_events` table every 2 seconds for rows where `processed = false`.
3.  For each unprocessed event, the API service triggers the **AI Enrichment** logic if it's a code-changing event (e.g., a new PR or a push to an existing one).
4.  The generated analysis is saved to the `insights` table.
5.  The `raw_events` row is marked as `processed = true`.
6.  Finally, the service fetches the complete, latest state of the affected pull request and **broadcasts it via WebSocket** to all connected Flutter clients.

---

## 3. Getting Started

### Prerequisites
*   Python 3.11+
*   A running YugabyteDB (or any PostgreSQL-compatible) instance.
*   API Key for Google Gemini.

### Setup & Installation
1.  **Clone the repository:**
    ```bash
    git clone <repository_url>
    cd api_service
    ```
2.  **Create and activate a virtual environment:**
    ```bash
    python -m venv __venv__
    source __venv__/bin/activate
    ```
3.  **Install dependencies:**
    ```bash
    pip install -r requirements.txt
    ```
4.  **Configure environment variables:**
    Copy the example file and fill in your details.
    ```bash
    cp .env.example .env
    ```
    Now, edit `.env`:
    ```env
    # .env
    DEBUG=True
    HOST="0.0.0.0"
    PORT=8000
    DATABASE_URL="postgresql://user:password@host/dbname?sslmode=require"
    GEMINI_API_KEY="your_google_gemini_api_key_here"
    ```
5.  **Run the service:**
    > `for single worker environment` 
    > ```bash
    >uvicorn app.main:app --reload
    >```
    > `For multiple workers using gunicorn`
    >```bash
    >python -m server_runner
    >```
    The API will be available at `http://localhost:8000`.

---

## 4. API Endpoints

This service exposes a REST API for initial data loading and a WebSocket for real-time updates.

### REST API

#### `GET /api/prs`
*   **Description:** Fetches an array of all pull requests, formatted for the main dashboard view. This should be called once when the Flutter app starts.
*   **Success Response (200 OK):**
    ```json
    [
      {
        "number": 101,
        "title": "Fix: Payment processing fails for international cards",
        "author": "frontend-dev",
        "authorAvatar": "https://avatars.githubusercontent.com/u/3",
        "commitSha": "f4b3c2d1a0e9f8g7h6i5j4k3l2m1n0o9",
        "repositoryName": "DevByZero/FlowLens-Demo",
        "createdAt": "2025-08-31T05:42:59.568393+00:00",
        "updatedAt": "2025-08-31T05:42:59.568393+00:00",
        "status": "pending",
        "filesChanged": "[]",
        "additions": 15,
        "deletions": 12,
        "branchName": "hotfix/payment-gateway",
        "isDraft": false
      }
    ]
    ```

#### `GET /api/insights/{pr_number}`
*   **Description:** Fetches a list of all historical AI-generated insights for a specific pull request, ordered from newest to oldest.
*   **Success Response (200 OK):**
    ```json
    [
      {
        "id": "464fbd91-f695-46d0-b8a3-fcd5e6c5c71e",
        "prNumber": 101,
        "commitSha": "f4b3c2d1a0e9f8g7h6i5j4k3l2m1n0o9",
        "riskLevel": "high",
        "summary": "This change will not resolve the critical payment processing issue...",
        "recommendation": "Do not merge this commit. Investigate why the commit is empty...",
        "createdAt": "2025-08-31T05:43:10.851242+00:00",
        "keyChanges": [],
        "confidenceScore": 0
      }
    ]
    ```

#### `GET /api/repository`
*   **Description:** Returns static metadata about the repository being monitored.
*   **Success Response (200 OK):**
    ```json
    {
      "name": "FlowLens-Demo",
      "fullName": "DevByZero/FlowLens-Demo",
      "description": "AI-Powered DevOps Workflow Visualizer",
      "owner": "DevByZero",
      "ownerAvatar": "https://avatars.githubusercontent.com/u/1",
      "isPrivate": true,
      "defaultBranch": "main",
      "openPRs": 1,
      "totalPRs": 10,
      "lastActivity": "2025-08-30T10:00:00Z",
      "languages": ["Dart", "Python", "Node.js"],
      "stars": 42,
      "forks": 12
    }
    ```

### WebSocket

#### `GET /ws`
*   **Description:** Establishes a WebSocket connection for receiving real-time updates.
*   **Connection URL:** `ws://<your_api_host>/ws`
*   **Message Format:** The server pushes messages to the client. The client does not need to send messages. Each message is a JSON object with two keys: `event` and `data`.
*   **Event Type: `pr_update`**
    *   This is the primary event type. It is sent whenever any aspect of a pull request changes (e.g., new AI insight, build status update).
    *   The `data` payload contains the **complete, updated state** of the pull request, including nested `pipeline_status` and the latest `ai_insight`.
    *   **Example Message:**
        ```json
        {
          "event": "pr_update",
          "data": {
            "pr_number": 101,
            "title": "Fix: Payment processing fails...",
            "updated_at": "2025-08-31T05:42:59.568393+00:00",
            "pipeline_status": {
              "status_pr": "opened",
              "status_build": "pending",
              "status_approval": "pending",
              "status_merge": "pending"
            },
            "ai_insight": {
              "risk_level": "High",
              "summary": "This change will not resolve the critical payment..."
            }
          }
        }
        ```

---

## 5. Integration Guide

### For the Ingestion Service (Node.js) Developer
This API service relies on the ingestion service to perform two critical tasks for every relevant GitHub webhook:
1.  **State Management:** Accurately insert and update records in the `pull_requests_view` and `pipeline_runs` tables. These tables are considered the source of truth for PR metadata and status.
2.  **Triggering:** For **every event** that the API service might care about (PRs, workflows, etc.), you **must** insert a corresponding record into the `raw_events` table with `processed = false`. This is the handshake that triggers our AI enrichment and WebSocket broadcast.

### For the Frontend (Flutter) Developer
Your interaction with this service follows a simple two-step pattern:
1.  **Initial Load:** On application startup, make a single `GET` request to `/api/prs` to populate your dashboard with the current state of all pull requests.
2.  **Live Updates:** Immediately after the initial load, establish a persistent connection to the `/ws` endpoint. Listen for `pr_update` messages. When a message arrives, find the corresponding pull request in your local state by its `pr_number` and replace it with the new data from the `data` payload. You do not need to make another REST API call.

---

## 6. Interactive API Documentation

For live testing and detailed schema information, this FastAPI service provides auto-generated, interactive documentation:

*   **Swagger UI:** [http://localhost:8000/docs](http://localhost:8000/docs)
*   **ReDoc:** [http://localhost:8000/redoc](http://localhost:8000/redoc)

These tools allow you to execute API calls directly from your browser and view detailed request/response models.