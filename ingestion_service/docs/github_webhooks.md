# GitHub Webhook Setup Guide

This guide details how to set up GitHub webhooks to send events to your deployed FlowLens Ingestion Service.

## 1. Prerequisites
- Your Ingestion Service must be deployed and publicly accessible via a URL (e.g., on Render).
- You must have a securely generated webhook secret key.

## 2. Webhook Configuration Steps

1.  **Navigate to Webhook Settings**:
    - Go to your target GitHub repository.
    - Click **Settings > Webhooks**.
    - Click **Add webhook**.

2.  **Configure the Payload URL**:
    - Enter the public URL of your deployed Ingestion Service, followed by `/webhook`.
    - Example: `https://your-app-name.onrender.com/webhook`

3.  **Set the Content Type**:
    - Change the content type to `application/json`.

4.  **Add Your Secret**:
    - Paste your generated webhook secret into the "Secret" field. This is critical for security and must match the `GITHUB_WEBHOOK_SECRET` environment variable in your service.

5.  **Select Events to Send**:
    - Choose "Let me select individual events."
    - Select the following essential events:
      - [x] **Pull requests**
      - [x] **Workflow runs**
      - [x] **Check runs**
      - [x] **Check suites**
      - [x] **Pull request reviews**

6.  **Activate the Webhook**:
    - Ensure "Active" is checked.
    - Click **Add webhook**.

## 3. Verify the Setup
GitHub will immediately send a `ping` event. In the webhook settings, you should see a green checkmark indicating a successful delivery with a `200 OK` response from your service.

## 4. Monitoring and Debugging
- **GitHub's "Recent Deliveries" Tab**: This interface is invaluable for debugging. You can inspect the exact request headers and payloads sent by GitHub, as well as the response received from your service.
- **Service Logs**: Monitor the logs of your Ingestion Service (e.g., via the Render dashboard) to see real-time processing of incoming events.
- **Redeliver Events**: You can use the "Redeliver" button in the GitHub UI to resend a specific event, which is useful for testing without having to perform the GitHub action again.

</br>

> ‎ 
> **</> Built by Mission Control | DevByZero 2025**
>
> *Defining the infinite possibilities in your DevOps pipeline.*
> ‎ 
