# Render Deployment Guide - Discord Mode

This guide walks you through deploying the FlowLens ingestion service to Render for testing GitHub webhooks with Discord logging.

## 🎯 Overview

This deployment will:

- Deploy the ingestion service to Render (free tier)
- Forward all GitHub webhook events to Discord for testing
- Save event logs to files for debugging
- Provide a public webhook endpoint for GitHub

## 🚀 Step 1: Prepare for Deployment

### Generate Webhook Secret

First, generate a secure webhook secret:

```bash
# Using Node.js
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"

# Using PowerShell (Windows)
[System.Web.Security.Membership]::GeneratePassword(64, 0)
```

**Save this secret!** You'll need it for both Render and GitHub configuration.

### Environment Variables for Render

You'll need these environment variables:

```bash
GITHUB_WEBHOOK_SECRET=your_generated_secret_here
NODE_ENV=production
PORT=3000
```

## 🌐 Step 2: Deploy to Render

### 2.1 Connect GitHub Repository

1. Go to [Render Dashboard](https://dashboard.render.com/)
2. Click **"New +"** → **"Web Service"**
3. Connect your GitHub account if not already connected
4. Select repository: `DevOps-Malayalam/mission-control`
5. Click **"Connect"**

### 2.2 Configure Service Settings

**Basic Settings:**

- **Name**: `flowlens-ingestion-discord`
- **Branch**: `feature/dev-jitto` (or your current branch)
- **Root Directory**: `ingestion_service`
- **Runtime**: `Node`

**Build & Deploy Settings:**

- **Build Command**: `npm install`
- **Start Command**: `node index-discord.js`

**Instance Type:**

- Select **"Free"** (sufficient for testing)

### 2.3 Set Environment Variables

In the **Environment** section, add:

| Key                     | Value                        |
| ----------------------- | ---------------------------- |
| `GITHUB_WEBHOOK_SECRET` | `your_generated_secret_here` |
| `NODE_ENV`              | `production`                 |
| `PORT`                  | `3000`                       |

### 2.4 Deploy

1. Click **"Create Web Service"**
2. Wait for deployment (usually 2-3 minutes)
3. Note your service URL: `https://flowlens-ingestion-discord.onrender.com`

## ✅ Step 3: Verify Deployment

### Test Health Endpoint

Visit your deployed service:

```
https://flowlens-ingestion-discord.onrender.com/health
```

Expected response:

```json
{
  "status": "healthy",
  "service": "FlowLens Ingestion Service (Discord Mode)",
  "timestamp": "2025-08-31T...",
  "discordWebhook": "configured",
  "features": ["github-webhooks", "discord-logging", "file-logging"]
}
```

### Test Discord Integration

Send a test message to Discord:

```bash
curl -X POST https://flowlens-ingestion-discord.onrender.com/test-discord
```

You should see a test message appear in your Discord channel.

## 🔗 Step 4: Configure GitHub Webhook

### 4.1 Access Repository Settings

1. Go to: `https://github.com/DevOps-Malayalam/mission-control`
2. Click **Settings** tab
3. Click **Webhooks** in left sidebar
4. Click **Add webhook**

### 4.2 Configure Webhook

**Payload URL:**

```
https://flowlens-ingestion-discord.onrender.com/webhook
```

**Content type:**

```
application/json
```

**Secret:**

```
your_generated_secret_here
```

**SSL verification:**

```
✅ Enable SSL verification
```

### 4.3 Select Events

Choose **"Let me select individual events"** and select:

✅ **Core Events:**

- [x] Pull requests
- [x] Workflow runs
- [x] Check runs
- [x] Check suites
- [x] Pull request reviews

✅ **Additional Events (optional):**

- [x] Pushes
- [x] Pull request review comments
- [x] Issue comments

### 4.4 Activate Webhook

1. Ensure **Active** is checked
2. Click **Add webhook**

GitHub will immediately send a `ping` event to test connectivity.

## 🧪 Step 5: Test the Integration

### Verify Webhook Connection

In the GitHub webhook settings, you should see:

- ✅ Green checkmark next to the webhook
- Recent delivery with `ping` event showing `200` response

### Check Discord Channel

You should see a message like:

```
🚀 FlowLens Webhook Event: ping
🕐 Time: 2025-08-31T...
📦 Delivery ID: abc-123...
🏓 Repository: DevOps-Malayalam/mission-control
✅ Webhook configured successfully!
```

### Test with Real Events

Create a test PR to trigger webhook events:

1. Create a new branch: `test/webhook-integration`
2. Make a small change (e.g., add a comment to README)
3. Create a pull request
4. Watch Discord for `pull_request` event

## 📊 Step 6: Monitor and Debug

### View Event Logs

Check recent events via the API:

```
https://flowlens-ingestion-discord.onrender.com/events
```

### Render Service Logs

1. Go to your Render service dashboard
2. Click **"Logs"** tab
3. Monitor real-time logs for webhook events

**Expected log output:**

```
📥 Received pull_request event (delivery: abc-123)
🕐 Timestamp: 2025-08-31T...
💾 Saved event to: 2025-08-31T..._pull_request_abc-123.json
✅ Successfully sent to Discord: pull_request
✅ Successfully processed pull_request event
```

### Discord Message Format

Each webhook event will appear in Discord as an embed with:

- **Event type** and **timestamp**
- **Event summary** (PR details, workflow status, etc.)
- **Truncated JSON payload** for debugging
- **Color coding** based on event type and status

## 🔧 Troubleshooting

### Common Issues

**1. Webhook returning 401 Unauthorized**

- Verify `GITHUB_WEBHOOK_SECRET` matches in both Render and GitHub
- Check that secret is exactly the same (no extra spaces/characters)

**2. Discord messages not appearing**

- Discord webhook URL might be invalid
- Check service logs for Discord API errors
- Verify Discord channel permissions

**3. Service not responding**

- Check Render service status in dashboard
- Verify environment variables are set correctly
- Check if service is sleeping (free tier sleeps after 15 minutes of inactivity)

**4. Events not being received**

- Verify webhook URL is correct
- Check GitHub webhook delivery history
- Ensure selected events include the ones you're testing

### Wake Up Sleeping Service

Render's free tier services sleep after 15 minutes of inactivity. To wake it up:

```bash
# Ping the health endpoint
curl https://flowlens-ingestion-discord.onrender.com/health
```

### View Specific Event Details

To see full event payload:

```
https://flowlens-ingestion-discord.onrender.com/events/2025-08-31T..._pull_request_abc-123.json
```

## 📋 Next Steps

Once webhook integration is working:

1. ✅ **Verify Events**: Test different GitHub events (PR, push, workflow)
2. 🔜 **Set up YugabyteDB**: Create and configure database
3. 🔜 **Build AI Service**: Create Python FastAPI service for Gemini integration
4. 🔜 **Connect Flutter**: Integrate real-time updates with your Flutter app

## 🛡️ Security Notes

- ✅ Webhook signatures are verified using HMAC-SHA256
- ✅ HTTPS is enforced for all communications
- ✅ Secrets are stored securely in Render environment variables
- ✅ Raw payloads are logged locally for debugging (not exposed via API)

## 📈 Performance Notes

- **Free Tier Limitations**: Service sleeps after 15 minutes of inactivity
- **Response Time**: Should respond to webhooks within 30 seconds
- **Rate Limits**: No specific limits for webhook processing
- **Storage**: Event files are stored in service filesystem (ephemeral)

---

🎉 **Your Discord webhook integration is now ready!**

You'll now see all GitHub events from your repository in Discord for testing and development purposes.
