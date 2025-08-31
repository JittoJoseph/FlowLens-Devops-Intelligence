# GitHub Webhook Setup Guide for FlowLens

This guide will walk you through setting up GitHub webhooks to send events to your FlowLens ingestion service.

## 🎯 What are GitHub Webhooks?

GitHub webhooks are HTTP callbacks that GitHub sends to your service when specific events happen in your repository (like PR creation, commits, CI/CD runs, etc.).

## 🚀 Step-by-Step Setup

### 1. Deploy Your Ingestion Service First

Before setting up webhooks, make sure your ingestion service is deployed and accessible:

- **Local Development**: Use ngrok to expose your local server
- **Production**: Deploy to Render, Heroku, or similar platform

### 2. Generate Webhook Secret

For security, generate a random secret key:

```bash
# Using Node.js
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"

# Using OpenSSL
openssl rand -hex 32

# Using PowerShell
[System.Web.Security.Membership]::GeneratePassword(64, 0)
```

Save this secret - you'll need it for both GitHub and your service configuration.

### 3. Repository Webhook Setup

#### Step 3.1: Navigate to Webhook Settings

1. Go to your GitHub repository: `https://github.com/DevOps-Malayalam/mission-control`
2. Click **Settings** tab
3. In the left sidebar, click **Webhooks**
4. Click **Add webhook**

#### Step 3.2: Configure Webhook

Fill in the webhook form:

**Payload URL:**

```
# For production (Render)
https://your-app-name.onrender.com/webhook

# For local development (ngrok)
https://abc123.ngrok.io/webhook
```

**Content type:**

```
application/json
```

**Secret:**

```
your_generated_secret_from_step_2
```

#### Step 3.3: Select Events

Choose **"Let me select individual events"** and select these events:

✅ **Essential Events:**

- [x] **Pull requests** - PR opened, closed, merged
- [x] **Workflow runs** - CI/CD pipeline execution
- [x] **Check runs** - Individual check results
- [x] **Check suites** - Check suite completion
- [x] **Pull request reviews** - Code review submissions

✅ **Optional Events (for enhanced tracking):**

- [x] **Pushes** - Code pushes to branches
- [x] **Pull request review comments** - Review comments
- [x] **Issue comments** - Comments on PRs
- [x] **Workflow jobs** - Individual job status

#### Step 3.4: Activate Webhook

1. Ensure **Active** is checked
2. Click **Add webhook**

### 4. Test the Webhook

GitHub will immediately send a `ping` event to test the webhook:

#### Expected Response:

- **Status**: ✅ Green checkmark
- **Response**: `200 OK`
- **Recent Deliveries**: Shows successful ping

#### If you see errors:

- ❌ Red X means connection failed
- Check the webhook URL is accessible
- Verify your service is running

### 5. Webhook Security Configuration

#### Environment Variables

Update your ingestion service `.env` file:

```bash
# Same secret used in GitHub webhook
GITHUB_WEBHOOK_SECRET=your_generated_secret_here

# Database and other configs
DATABASE_URL=your_yugabyte_connection_string
PORT=3000
NODE_ENV=production
```

#### Signature Verification

Your ingestion service automatically verifies GitHub signatures using HMAC-SHA256. The service will:

✅ **Accept** requests with valid signatures  
❌ **Reject** requests with invalid/missing signatures

## 🔧 Local Development Setup

### Using ngrok for Local Testing

1. **Install ngrok:**

   ```bash
   # Download from https://ngrok.com/download
   # Or install via npm
   npm install -g ngrok
   ```

2. **Start your local service:**

   ```bash
   cd ingestion_service
   npm run dev
   ```

3. **Expose local server:**

   ```bash
   # In another terminal
   ngrok http 3000
   ```

4. **Use ngrok URL in webhook:**
   ```
   https://abc123.ngrok.io/webhook
   ```

## 📋 Event Types and Payloads

### Pull Request Events

**Triggers:** PR opened, closed, merged, synchronized

**Key Payload Fields:**

```json
{
  "action": "opened|closed|synchronize",
  "pull_request": {
    "number": 123,
    "title": "Add new feature",
    "user": {
      "login": "username",
      "avatar_url": "https://github.com/user.png"
    },
    "head": {
      "sha": "commit_hash",
      "ref": "feature-branch"
    },
    "additions": 150,
    "deletions": 20,
    "merged": false
  }
}
```

### Workflow Run Events

**Triggers:** CI/CD workflow started, completed

**Key Payload Fields:**

```json
{
  "action": "requested|in_progress|completed",
  "workflow_run": {
    "name": "CI",
    "status": "completed",
    "conclusion": "success|failure",
    "pull_requests": [{ "number": 123 }]
  }
}
```

### Check Run Events

**Triggers:** Individual checks (tests, linting, etc.)

**Key Payload Fields:**

```json
{
  "action": "created|completed",
  "check_run": {
    "name": "Tests",
    "status": "completed",
    "conclusion": "success|failure",
    "pull_requests": [{ "number": 123 }]
  }
}
```

## 🔍 Monitoring and Debugging

### GitHub Webhook Delivery Dashboard

1. Go to **Settings → Webhooks**
2. Click on your webhook
3. View **Recent Deliveries** tab

**Delivery Information:**

- **Request**: Shows the payload sent
- **Response**: Shows your service's response
- **Headers**: Includes signature and delivery ID

### Common Response Codes

| Code   | Meaning      | Action                    |
| ------ | ------------ | ------------------------- |
| 200 ✅ | Success      | Webhook working correctly |
| 401 ❌ | Unauthorized | Check webhook secret      |
| 404 ❌ | Not Found    | Verify webhook URL        |
| 500 ❌ | Server Error | Check service logs        |

### Service Logs

Monitor your ingestion service logs:

```bash
# Successful processing
📥 Received pull_request event (delivery: abc-123)
🔄 Processing pull_request event...
📋 PR #42 - opened
📊 Updated PR #42: status_pr = opened
✅ Successfully processed pull_request event (ID: uuid)

# Error example
❌ Invalid webhook signature
❌ Database connection failed
```

## 🔄 Webhook Management

### Update Webhook Configuration

1. Go to **Settings → Webhooks**
2. Click **Edit** on your webhook
3. Update URL, secret, or events
4. Click **Update webhook**

### Test Specific Events

You can trigger webhook events by:

1. **Creating a test PR** - Triggers `pull_request` event
2. **Pushing code** - Triggers `push` and potentially `workflow_run`
3. **Reviewing PR** - Triggers `pull_request_review`
4. **Merging PR** - Triggers `pull_request` with action "closed"

### Webhook Redeliver

To resend a webhook delivery:

1. Go to **Recent Deliveries**
2. Click on a delivery
3. Click **Redeliver**

## 🛡️ Security Best Practices

### 1. Always Use Secrets

- Never skip webhook secret configuration
- Use a strong, random secret (32+ characters)
- Rotate secrets periodically

### 2. Validate Signatures

- Your service automatically validates HMAC-SHA256 signatures
- Reject requests with invalid signatures

### 3. HTTPS Only

- Use HTTPS URLs for webhooks
- GitHub requires HTTPS for production webhooks

### 4. IP Filtering (Optional)

GitHub webhook requests come from these IP ranges:

```
192.30.252.0/22
185.199.108.0/22
140.82.112.0/20
143.55.64.0/20
2a0a:a440::/29
2606:50c0::/32
```

## 🚨 Troubleshooting

### Webhook Not Receiving Events

**Check List:**

1. ✅ Service is running and accessible
2. ✅ Webhook URL is correct
3. ✅ Required events are selected
4. ✅ Webhook is Active
5. ✅ No firewall blocking requests

### Signature Verification Failing

**Common Causes:**

- Different secrets in GitHub vs service
- Encoding issues with secret
- Missing `X-Hub-Signature-256` header

**Solution:**

```bash
# Verify your secret matches exactly
echo $GITHUB_WEBHOOK_SECRET
```

### High Latency or Timeouts

**GitHub Requirements:**

- Respond within **30 seconds**
- Return HTTP status code

**Optimization:**

- Process events asynchronously
- Use database connection pooling
- Return 200 immediately, process in background

## 📈 Advanced Configuration

### Organization-Level Webhooks

For multiple repositories:

1. Go to **Organization Settings**
2. **Webhooks** → **Add webhook**
3. Configure same as repository webhook
4. Receives events from all repos in org

### Webhook Filtering

GitHub sends all configured events. Filter in your service:

```javascript
// Only process specific repositories
if (payload.repository.full_name !== "DevOps-Malayalam/mission-control") {
  return res.status(200).json({ message: "Repository ignored" });
}

// Only process main branch pushes
if (eventType === "push" && payload.ref !== "refs/heads/main") {
  return res.status(200).json({ message: "Branch ignored" });
}
```

## 🎯 Next Steps

Once webhooks are configured:

1. ✅ **Test Events**: Create a test PR to verify webhook delivery
2. 🔜 **Monitor Logs**: Watch your service process events
3. 🔜 **Build API Service**: Create the AI processing service
4. 🔜 **Connect Flutter**: Integrate real-time updates

---

🎉 **Your GitHub webhooks are now ready for FlowLens!**

The ingestion service will automatically:

- Receive and validate webhook events
- Store raw events in YugabyteDB
- Extract PR and pipeline data
- Update workflow status in real-time
