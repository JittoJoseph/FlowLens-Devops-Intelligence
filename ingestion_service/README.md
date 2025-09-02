# FlowLens Ingestion Service: The Real-Time Data Gateway

The FlowLens Ingestion Service is the secure, highly-available front door for the entire FlowLens ecosystem. As a dedicated microservice, its sole responsibility is to ingest, validate, and persist real-time transactional data from GitHub into our distributed YugabyteDB backend. This focused design is key to our system's overall `scalability` and `security`.

## Key Features

- **Secure Webhook Gateway**: Implements HMAC-SHA256 signature verification to ensure that only legitimate, trusted data enters the system.
- **Decoupled Persistence Layer**: Immediately writes data to YugabyteDB and flags it for processing, creating a durable, asynchronous workflow that enhances system resilience.
- **High-Throughput Design**: Built with Node.js and Express to handle a high volume of concurrent webhook events without blocking, essential for enterprise-scale operations.
- **Deployment Ready**: Optimized for cloud-native deployment on platforms like Render, with built-in health checks and structured logging for production environments.

## Getting Started

### Prerequisites

- Node.js 18+
- Access to the FlowLens YugabyteDB instance.

### Setup & Run

1.  **Clone and navigate to the service:** `git clone <repo> && cd ingestion_service`
2.  **Install dependencies:** `npm install`
3.  **Configure environment:** Copy `.env.example` to `.env` and fill in your `DATABASE_URL` and `GITHUB_WEBHOOK_SECRET`.
4.  **Start the service:** `npm run dev`

The service will be available at `http://localhost:3000`.

## Documentation

- **[Deployment Guide](./docs/deployment.md)**: Step-by-step instructions for deploying to the cloud.
- **[GitHub Webhook Setup](./docs/github_webhooks.md)**: How to configure the data source.
- **[Integration Guide](./docs/integration_guide.md)**: The data contract for this microservice.