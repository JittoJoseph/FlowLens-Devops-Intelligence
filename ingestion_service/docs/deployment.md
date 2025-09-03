# Deployment Guide (Render)

This guide provides instructions for deploying the FlowLens Ingestion Service to [Render](https://render.com), a cloud platform with a generous free tier ideal for this project.

## 1. Prerequisites

- A Render account, connected to your GitHub account.
- Your repository forked and available in your GitHub account.
- Your YugabyteDB `DATABASE_URL` and a `GITHUB_WEBHOOK_SECRET`.

## 2. Standard Deployment Steps

1.  **Create a New Web Service**: From the Render dashboard, click **New+ > Web Service** and select your forked repository.

2.  **Configure Settings**:
    - **Name**: `flowlens-ingestion-service`
    - **Region**: Choose a region close to you.
    - **Branch**: `main` (or your primary development branch).
    - **Runtime**: `Node`.
    - **Build Command**: `npm install`.
    - **Start Command**: `npm start`.
    - **Instance Type**: `Free`.

3.  **Add Environment Variables**: Under the "Advanced" section, add the following environment variables:
    | Key | Value |
    | :--- | :--- |
    | `DATABASE_URL` | Your YugabyteDB connection string. |
    | `GITHUB_WEBHOOK_SECRET` | The secret key you generated for your webhook. |
    | `NODE_ENV` | `production` |
    | `PORT` | `3000` |

4.  **Deploy**: Click **Create Web Service**. Render will automatically build and deploy your service.

5.  **Update GitHub Webhook**: Once deployed, copy the service URL (e.g., `https://flowlens-ingestion-service.onrender.com`) and use it as the "Payload URL" in your GitHub webhook configuration.

## 3. Deploying for Debugging (Discord Mode)

For debugging purposes, you can deploy a version of the service that forwards all webhook payloads to a Discord channel.

**Follow the standard deployment steps above with one change:**

-   **Modify the Start Command**:
    - **Start Command**: `node index-discord.js`

This will run the alternative entry point that logs events to Discord instead of (or in addition to) writing to the database, which is useful for verifying webhook delivery and payload structure. Ensure the `DISCORD_WEBHOOK_URL` environment variable is also set if required by `index-discord.js`.

## Monitoring and Logs

You can monitor the health of your deployed service, view real-time logs, and manage environment variables directly from the Render dashboard. Check the logs to confirm that webhook events are being received and processed successfully.