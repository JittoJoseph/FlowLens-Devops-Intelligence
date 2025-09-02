# FlowLens API Service v2.0

The FlowLens API Service is the central intelligence layer for the FlowLens platform. Written in Python using FastAPI, it polls the database for changes, generates AI-powered insights, and serves data to clients through REST APIs and WebSockets.

## Key Features

- **Repository-Centric Architecture**: Full support for managing and filtering data across multiple repositories.
- **Polling-Based Processing**: A reliable 2-second database poller processes new events flagged for processing.
- **Enhanced AI Insights**: Advanced analysis of file changes and diffs using Google Gemini.
- **Flexible APIs**: Modern RESTful endpoints with repository filtering capabilities.
- **Real-Time Broadcasting**: Pushes live state updates to all connected clients via WebSockets.

## Getting Started

### Prerequisites

- Python 3.11+
- Access to a YugabyteDB instance with the FlowLens schema applied.
- A Google Gemini API key.

### Setup & Run

1.  **Clone the repository and navigate to the service:**
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
4.  **Configure environment:**
    - Copy `.env.example` to `.env`.
    - Edit `.env` with your `DATABASE_URL` and `GEMINI_API_KEY`.
    - Ensure `EVENT_PROCESSING_MODE` is set to `POLL`.

5.  **Run the service:**
    ```bash
    # For development with auto-reload
    uvicorn app.main:app --reload

    # For production
    python server_runner.py
    ```
The service will be available at `http://localhost:8000`.

## Documentation

- **[API Endpoints](./docs/api_endpoints.md)**: Detailed descriptions of all REST endpoints.
- **[WebSocket Guide](./docs/websockets.md)**: Information on the real-time WebSocket protocol.
- **[AI Insights System](./docs/ai_insights.md)**: How the AI processing flow works.
- **[Integration Guide](./docs/integration_guide.md)**: Guidelines for developers interacting with this service.