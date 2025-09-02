# FlowLens Ingestion Service

The FlowLens Ingestion Service is a robust Node.js application that serves as the entry point for all data from GitHub. It securely receives webhook events, validates them, and persists them to the YugabyteDB database for later processing by the API Service.

## Key Features

- **Secure Webhook Handling**: Validates GitHub webhook payloads using HMAC-SHA256 signature verification.
- **Reliable Data Persistence**: Stores event data in a structured, repository-centric schema in YugabyteDB.
- **Asynchronous Processing Support**: Sets `processed = FALSE` flags to enable the decoupled API service to poll for new work.
- **Production Ready**: Designed for deployment on platforms like Render, with health checks and comprehensive logging.

## Getting Started

### Prerequisites

- Node.js 18+
- Access to a YugabyteDB instance with the FlowLens schema applied.

### Setup & Run

1.  **Clone the repository and navigate to the service:**
    ```bash
    git clone <repository_url>
    cd ingestion_service
    ```
2.  **Install dependencies:**
    ```bash
    npm install
    ```
3.  **Configure environment:**
    - Copy `.env.example` to `.env`.
    - Edit `.env` with your `DATABASE_URL` and `GITHUB_WEBHOOK_SECRET`.

4.  **Start the service:**
    ```bash
    # For development with auto-reload
    npm run dev

    # For production
    npm start
    ```
The service will be available at `http://localhost:3000`.

## Documentation

- **[Deployment Guide](./docs/deployment.md)**: Step-by-step instructions for deploying to Render.
- **[GitHub Webhook Setup](./docs/github_webhooks.md)**: How to configure GitHub to send events to this service.
- **[Integration Guide](./docs/integration_guide.md)**: Critical information for developers working on this service.