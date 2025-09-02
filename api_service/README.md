# FlowLens API Service v2.0 - Repository-Centric Architecture

## 1. Overview

The FlowLens API Service v2.0 is the central intelligence layer for the FlowLens platform, completely refactored to support a **repository-centric architecture**. Written in Python using FastAPI, it provides:

- **Repository Management:** Multi-repository support with comprehensive metadata tracking
- **Real-time Processing:** Direct database trigger integration for instant event processing
- **Enhanced AI Insights:** Advanced file change analysis using Google Gemini with actual diff data
- **Flexible APIs:** New RESTful endpoints with optional repository filtering
- **WebSocket Broadcasting:** Real-time updates for all connected clients

This service transforms raw GitHub webhook data into actionable intelligence across multiple repositories.

---

## 2. Architecture & Data Flow - v2.0

The new architecture uses **database triggers** for real-time event processing, eliminating the need for a `raw_events` table and providing instant responsiveness.

```
+-------------------+      (Webhook)       +---------------------+
|      GitHub       | -------------------> | Ingestion Service   |
| (Multiple Repos)  |                      |      (Node.js)      |
+-------------------+                      +----------+----------+
                                                      | (Direct Table Writes)
                                                      v
+----------------------------------------------------------------------------------------------------------------------+
|                                    Database (YugabyteDB) - Repository-Centric Schema                                |
|                                                                                                                      |
| +----------------+   +-------------------+   +-------------------+   +-------------------+   +-----------------+   |
| | repositories   |   | pull_requests     |   | pipeline_runs     |   | insights          |   | DB Triggers     |   |
| | (master data)  |<--| (linked by        |   | (status tracking) |   | (AI generated)    |   | (notifications) |   |
| |                |   |  repo_id)         |   | (repo_id + pr_#)  |   | (repo_id + pr_#)  |   |                 |   |
| +----------------+   +-------------------+   +-------------------+   +----------+--------+   +--------+--------+   |
+------------------------------------------------------------------------------------------------------------------------+
                                      ^                                              |                     |
                                      | (Real-time Queries)                         | (AI Processing)     | (Notifications)
                                      |                                              v                     v
+-----------------------------------------------------------------------------------------------------------------+
|                                        FlowLens API Service v2.0 (Python)                               |
|                                                                                                         |
|  +--------------------+     +-------------------------+     +----------------------------------+        |
|  | DB Trigger Listener| --> | AI Insights (Enhanced)  | --> | Repository-Aware Broadcasting   |        |
|  | (3 event types)    |     | (files_changed analysis)|     | (WebSocket + REST APIs)         |        |
|  +--------------------+     +-------------------------+     +----------------------------------+        |
+-----------------------------------------------------------------------------------------------------------------+
                                             | (Repository-filtered APIs)
                                             | (Real-time WebSocket updates)
                                             v
                                     +-------+-------+
                                     | Flutter App   |
                                     | (Multi-repo)  |
                                     +---------------+
```

**Key Improvements in v2.0:**

1. **Database Triggers**: `pr_event`, `pipeline_event`, `insight_event` for instant notifications
2. **Repository-Centric**: All data linked through `repo_id` foreign keys
3. **Enhanced AI**: Uses actual `files_changed` JSON data with patches and diffs
4. **Multi-Repository**: Support for tracking multiple repositories simultaneously
5. **Flexible APIs**: Optional repository filtering across all endpoints

---

## 3. New API Endpoints v2.0

### Core Resource Endpoints

#### `GET /api/repositories`

- **Description:** Returns all repositories tracked by the system
- **Features:** Complete metadata, statistics, activity tracking
- **Response:** Array of repository objects with all database fields

#### `GET /api/pull-requests?repository_id={uuid}`

- **Description:** Returns pull requests with optional repository filtering
- **Query Parameters:**
  - `repository_id` (optional): Filter by specific repository UUID
- **Response:** Array of PR objects with complete metadata and file changes

#### `GET /api/pipelines?repository_id={uuid}`

- **Description:** Returns pipeline runs with optional repository filtering
- **Features:** Complete CI/CD status tracking, history timeline
- **Response:** Array of pipeline objects with status progression

#### `GET /api/insights?repository_id={uuid}`

- **Description:** Returns AI insights with optional repository filtering
- **Features:** Enhanced analysis using actual file changes and diffs
- **Response:** Array of insight objects with risk assessments

#### `GET /api/insights/{pr_number}?repository_id={uuid}`

- **Description:** Historical insights for a specific PR
- **Features:** Chronological insight evolution, cross-repository support
- **Response:** Array of insights for the specified PR

### Legacy Compatibility Endpoints

#### `GET /api/prs` (Legacy)

- **Description:** Aggregated PR data for existing Flutter apps
- **Features:** Maintains backward compatibility with v1.0 clients
- **Response:** Formatted for existing Flutter models

#### `GET /api/repository` (Legacy)

- **Description:** Repository metadata for single-repo clients
- **Features:** Returns primary repository or static demo data
- **Response:** Single repository object in v1.0 format

---

## 4. Enhanced AI Insights System

### Files Changed Analysis

The v2.0 system processes actual file change data from GitHub webhooks:

```json
{
  "files_changed": [
    {
      "filename": "src/app/page.tsx",
      "status": "modified",
      "additions": 20,
      "deletions": 99,
      "changes": 119,
      "patch": "@@ -14,107 +14,28 @@ export default function Home() {\n   };\n \n   return (\n-    <div className=\"min-h-screen bg-gradient..."
    }
  ]
}
```

### AI Processing Flow

1. **Trigger Detection:** New PR with `files_changed` data
2. **Data Extraction:** Parse filenames, changes, and diff patches
3. **Enhanced Prompting:** Send structured file analysis to Gemini
4. **Insight Generation:** Risk assessment, recommendations, key changes
5. **Storage & Broadcasting:** Save to `insights` table, notify clients

---

## 5. Real-Time Event Processing

### Database Trigger System

Three notification channels provide instant event processing:

- **`pr_event`**: Pull request creation, updates, merges
- **`pipeline_event`**: CI/CD status changes, build results
- **`insight_event`**: New AI insights generated

### Processing Pipeline

1. **Trigger Fires:** Database change detected
2. **Notification Sent:** Record UUID broadcasted via PostgreSQL NOTIFY
3. **Listener Receives:** API service processes notification instantly
4. **AI Generation:** Enhanced insights for PRs with file changes
5. **State Aggregation:** Complete repository/PR state assembled
6. **WebSocket Broadcast:** Real-time updates pushed to all clients

---

## 6. Getting Started v2.0

### Prerequisites

- Python 3.11+
- YugabyteDB with repository-centric schema
- Google Gemini API key

### Setup & Installation

1.  **Clone and navigate:**
    ```bash
    git clone <repository_url>
    cd api_service
    ```
2.  **Virtual environment:**
    ```bash
    python -m venv __venv__
    source __venv__/bin/activate  # or .\\__venv__\\Scripts\\activate on Windows
    ```
3.  **Install dependencies:**
    ```bash
    pip install -r requirements.txt
    ```
4.  **Configure environment:**

    ```bash
    cp .env.example .env
    ```

    Edit `.env` with your settings:

    ```env
    # Database Configuration
    DATABASE_URL="postgresql://user:password@host/dbname?sslmode=require"

    # AI Configuration
    GEMINI_API_KEY="your_google_gemini_api_key_here"
    GEMINI_AI_MODEL="gemini-2.5-flash"

    # Processing Mode (LISTEN for triggers, POLL for fallback)
    EVENT_PROCESSING_MODE="LISTEN"

    # Production Settings
    DEBUG=False
    WORKERS=1
    ```

5.  **Run the service:**

    ```bash
    # Development
    uvicorn app.main:app --reload

    # Production
    python server_runner.py
    ```

---

## 7. WebSocket Real-Time Updates

### Connection

- **URL:** `ws://localhost:8000/ws`
- **Protocol:** JSON message broadcasting

### Message Format

```json
{
  "event_type": "pr_update",
  "repository": {
    "id": "uuid",
    "name": "repository-name",
    "full_name": "owner/repository-name",
    "...": "all repository fields"
  },
  "pull_request": {
    "id": "uuid",
    "pr_number": 17,
    "title": "Feature implementation",
    "files_changed": [...],
    "...": "all PR fields"
  },
  "pipeline": {
    "status_pr": "pending",
    "status_build": "buildPassed",
    "status_approval": "pending",
    "status_merge": "merged",
    "...": "all pipeline fields"
  },
  "latest_insight": {
    "risk_level": "medium",
    "summary": "Significant UI changes detected",
    "recommendation": "Review styling impacts",
    "...": "all insight fields"
  },
  "timestamp": "2025-09-02T15:30:45.123Z"
}
```

---

## 8. Integration Guide v2.0

### For Ingestion Service Developers

**Critical Requirements:**

1. **Repository Management:** Check/create repositories before PR processing
2. **Foreign Key Linking:** All records must reference correct `repo_id`
3. **Files Changed Data:** Include complete `files_changed` JSON for AI processing
4. **No Raw Events:** Direct table writes trigger automatic processing

### For Frontend Developers

**Updated Integration Pattern:**

1. **Repository Selection:** Query `/api/repositories` for multi-repo support
2. **Filtered Queries:** Use `repository_id` parameter for focused views
3. **Enhanced Data:** Access complete file change information and insights
4. **WebSocket Handling:** Process aggregated state updates with repository context

---

## 9. Production Deployment

### Docker Support

```bash
# Build image
docker build -t flowlens-api:v2.0 .

# Run container
docker run -p 8000:8000 --env-file .env flowlens-api:v2.0
```

### Health Monitoring

- **Basic:** `GET /` - Service status and version
- **Detailed:** `GET /health` - Database connectivity and configuration

### Performance Features

- Database connection pooling with configurable limits
- Efficient SQL queries with proper indexing
- WebSocket connection management with automatic cleanup
- Graceful shutdown handling for zero-downtime deployments

---

## 10. API Documentation

**Interactive Documentation:**

- **Swagger UI:** [http://localhost:8000/docs](http://localhost:8000/docs)
- **ReDoc:** [http://localhost:8000/redoc](http://localhost:8000/redoc)

**Key Features:**

- Complete endpoint documentation with examples
- Repository filtering parameter explanations
- WebSocket message format specifications
- Error response handling guidelines

---

## 11. Changelog v1.0 → v2.0

### Major Changes

- ✅ **Repository-centric architecture** - Multi-repo support
- ✅ **Database trigger integration** - Real-time processing
- ✅ **Enhanced AI insights** - Actual file change analysis
- ✅ **Flexible API design** - Optional repository filtering
- ✅ **Improved WebSocket system** - Aggregated state broadcasting
- ❌ **Removed raw_events table** - Direct trigger-based processing
- ❌ **Removed event polling dependency** - Triggers provide real-time updates

### Backward Compatibility

- Legacy `/api/prs` and `/api/repository` endpoints maintained
- WebSocket message format enhanced but compatible
- Environment configuration extended with new options

---

This v2.0 architecture provides a robust, scalable foundation for multi-repository DevOps workflow visualization with real-time AI insights and comprehensive API flexibility.
