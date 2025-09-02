# FlowLens System Architecture

The FlowLens platform is designed with a service-oriented architecture that separates concerns for ingestion, processing, and presentation. The system uses a database-centric communication model, where the `Ingestion Service` writes data and the `API Service` polls for changes.

## Data Flow Diagram

```
+-------------------+      (Webhook)       +---------------------+
|      GitHub       | -------------------> | Ingestion Service   |
| (Multiple Repos)  |                      |      (Node.js)      |
+-------------------+                      +----------+----------+
                                                      | (Writes to tables)
                                                      | (Sets processed=FALSE)
                                                      v
+----------------------------------------------------------------------------------------------------------------------+
|                                    Database (YugabyteDB) - Repository-Centric Schema                                 |
|                                                                                                                      |
| +----------------+   +-------------------+   +-------------------+   +-------------------+   +-----------------+     |
| | repositories   |   | pull_requests     |   | pipeline_runs     |   | insights          |   | processed=FALSE |     |
| | (master data)  |<--| (linked by        |   | (status tracking) |   | (AI generated)    |   | (polling flags) |     |
| |                |   |  repo_id)         |   | (repo_id + pr_#)  |   | (repo_id + pr_#)  |   |                 |     |
| +----------------+   +-------------------+   +-------------------+   +----------+--------+   +--------+--------+     |
+----------------------------------------------------------------------------------------------------------------------+
                                      ^                                              |                     |
                                      | (2s Polling Queries)                         | (AI Processing)     | (State Changes)
                                      |                                              v                     v
+-----------------------------------------------------------------------------------------------------------------+
|                                        FlowLens API Service v2.0 (Python)                                       |
|                                                                                                                 |
|  +--------------------+     +-------------------------+     +----------------------------------+                |
|  | Database Poller    | --> | AI Insights (Enhanced)  | --> | Repository-Aware Broadcasting    |                |
|  | (processed=FALSE)  |     | (files_changed analysis)|     | (WebSocket + REST APIs)          |                |
|  +--------------------+     +-------------------------+     +----------------------------------+                |
+-----------------------------------------------------------------------------------------------------------------+
                                             | (Repository-filtered APIs)
                                             | (Real-time WebSocket updates)
                                             v
                                     +-------+-------+
                                     | Flutter App   |
                                     | (Multi-repo)  |
                                     +---------------+
```

## Core Principles

1.  **Repository-Centric:** All data is organized around repositories. This allows the platform to support multiple repositories seamlessly. Every key table (`pull_requests`, `pipeline_runs`, `insights`) is linked to the `repositories` table via a `repo_id` foreign key.

2.  **Polling-Based Processing:** The API Service uses a reliable 2-second database polling mechanism to detect changes. It queries for records where a `processed` flag is `FALSE`. This decouples the processing logic from the ingestion mechanism and ensures no events are missed, even during service downtime.

3.  **Decoupled Services:**
    *   The **Ingestion Service** is responsible only for receiving, validating, and storing webhook data. It performs no business logic.
    *   The **API Service** is the "brain," containing all business logic, AI integration, and client-facing communication (API and WebSockets).

4.  **Real-Time via Broadcasting:** After processing a change, the API Service broadcasts the updated state to all connected clients via WebSockets, ensuring the frontend is always synchronized.