# FlowLens Ingestion Service

🚀 **GitHub Webhook Processor for AI-Powered DevOps Workflow Visualization**

The Ingestion Service is a Node.js Express application that receives and processes GitHub webhook events, storing them in YugabyteDB for the FlowLens AI workflow visualization platform.

## 🔧 Features

- **GitHub Webhook Processing**: Secure webhook endpoint with signature verification
- **Event Storage**: Raw event storage in YugabyteDB with structured data extraction
- **Workflow Tracking**: Automatic PR pipeline status updates
- **Security**: HMAC-SHA256 signature verification for webhook authenticity
- **Health Monitoring**: Health check endpoints and comprehensive logging
- **Error Handling**: Graceful error handling with detailed logging

## 📋 Prerequisites

- Node.js 18+
- YugabyteDB Cloud account (free tier available)
- GitHub repository with webhook access

## 🚀 Quick Start

### 1. Environment Setup

Create a `.env` file in the `ingestion_service` directory:

```bash
# Database Configuration
DATABASE_URL=postgresql://username:password@host:port/database?ssl=true

# GitHub Webhook Security
GITHUB_WEBHOOK_SECRET=your_webhook_secret_here

# Server Configuration
PORT=3000
NODE_ENV=production
```

### 2. Install Dependencies

```bash
cd ingestion_service
npm install
```

### 3. Start the Service

```bash
# Development
npm run dev

# Production
npm start
```

## 🗄️ Database Setup

### YugabyteDB Cloud Setup

1. **Create Account**: Go to [YugabyteDB Cloud](https://cloud.yugabyte.com/) and sign up for free
2. **Create Cluster**: Create a new "Sandbox" cluster (free tier)
3. **Get Connection String**: Copy the connection string from the cluster dashboard
4. **Setup Tables**: Run the schema from the main project's `schema.sql`

### Required Tables

The service expects these tables to exist in your YugabyteDB:

```sql
-- Raw GitHub events storage
CREATE TABLE raw_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type TEXT NOT NULL,
  payload JSONB NOT NULL,
  delivery_id TEXT,
  processed BOOLEAN DEFAULT FALSE,
  received_at TIMESTAMPTZ DEFAULT now()
);

-- Pull request view for Flutter app
CREATE TABLE pull_requests_view (
  pr_number INT PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  author TEXT NOT NULL,
  author_avatar TEXT,
  commit_sha TEXT NOT NULL,
  repository_name TEXT DEFAULT 'DevOps-Malayalam/mission-control',
  branch_name TEXT,
  files_changed JSONB DEFAULT '[]'::jsonb,
  additions INT DEFAULT 0,
  deletions INT DEFAULT 0,
  is_draft BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Pipeline status tracking
CREATE TABLE pipeline_runs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pr_number INT UNIQUE NOT NULL,
  commit_sha TEXT,
  author TEXT,
  avatar_url TEXT,
  status_pr TEXT DEFAULT 'pending',
  status_build TEXT DEFAULT 'pending',
  status_approval TEXT DEFAULT 'pending',
  status_merge TEXT DEFAULT 'pending',
  updated_at TIMESTAMPTZ DEFAULT now()
);
```

## 📡 GitHub Webhook Setup

### 1. Repository Webhook

1. Go to your GitHub repository
2. Click **Settings** → **Webhooks** → **Add webhook**
3. Configure the webhook:

```
Payload URL: https://your-render-app.onrender.com/webhook
Content type: application/json
Secret: your_webhook_secret_here (same as GITHUB_WEBHOOK_SECRET)
```

4. **Select Events**: Choose "Let me select individual events" and select:

   - [x] Pull requests
   - [x] Workflow runs
   - [x] Check runs
   - [x] Check suites
   - [x] Pull request reviews
   - [x] Pushes

5. Ensure **Active** is checked and click **Add webhook**

### 2. Test Webhook

After setup, GitHub will send a `ping` event. Check your service logs for:

```
🏓 Ping event received - webhook is working!
```

## 🚀 Deployment on Render

### 1. Create Render Account

Sign up at [render.com](https://render.com) (free tier available)

### 2. Deploy Service

1. **Connect Repository**: Link your GitHub repository
2. **Create Web Service**:

   - **Environment**: Node
   - **Build Command**: `cd ingestion_service && npm install`
   - **Start Command**: `cd ingestion_service && npm start`
   - **Instance Type**: Free tier

3. **Environment Variables**:

   ```
   DATABASE_URL=your_yugabyte_connection_string
   GITHUB_WEBHOOK_SECRET=your_webhook_secret
   NODE_ENV=production
   ```

4. **Deploy**: Click "Create Web Service"

### 3. Update Webhook URL

Once deployed, update your GitHub webhook with the Render URL:

```
https://your-app-name.onrender.com/webhook
```

## 📊 API Endpoints

### Health Check

```bash
GET /health
```

Returns service status and timestamp.

### Webhook Processor

```bash
POST /webhook
```

Receives GitHub webhook events. Secured with HMAC-SHA256 signature verification.

### Recent Events (Debug)

```bash
GET /events?limit=20
```

Returns recent webhook events for debugging.

### Service Info

```bash
GET /
```

Returns service information and available endpoints.

## 🔄 Event Processing

The service processes these GitHub events:

| Event Type            | Description                | Actions                             |
| --------------------- | -------------------------- | ----------------------------------- |
| `pull_request`        | PR opened/updated/merged   | Updates PR data and pipeline status |
| `workflow_run`        | CI/CD workflow execution   | Updates build status                |
| `check_run`           | Individual check execution | Updates build status                |
| `check_suite`         | Check suite completion     | Updates build status                |
| `pull_request_review` | PR review submitted        | Updates approval status             |
| `push`                | Code pushed to repository  | Logs for reference                  |

## 📝 Scripts

Update your `package.json` scripts:

```json
{
  "scripts": {
    "start": "node index.js",
    "dev": "nodemon index.js",
    "test": "echo \"Error: no test specified\" && exit 1"
  }
}
```

## 🔍 Monitoring & Debugging

### Logs

The service provides detailed logging:

- ✅ Successful events
- ❌ Error events
- 📥 Incoming webhooks
- 📊 Status updates
- 🔄 Event processing

### Health Check

Monitor service health:

```bash
curl https://your-app.onrender.com/health
```

### Event History

View recent events:

```bash
curl https://your-app.onrender.com/events
```

## 🔒 Security

- **Webhook Signature Verification**: Uses HMAC-SHA256 to verify GitHub signatures
- **Environment Variables**: Sensitive data stored in environment variables
- **SSL/TLS**: All connections use HTTPS in production
- **Input Validation**: JSON payload validation and sanitization

## 🐛 Troubleshooting

### Common Issues

1. **Database Connection Failed**

   - Check DATABASE_URL environment variable
   - Ensure YugabyteDB cluster is running
   - Verify SSL settings

2. **Webhook Signature Verification Failed**

   - Check GITHUB_WEBHOOK_SECRET matches GitHub webhook config
   - Ensure webhook uses `application/json` content type

3. **Events Not Processing**
   - Check webhook delivery in GitHub settings
   - Verify webhook URL is accessible
   - Check service logs for errors

### Debug Mode

For development, set:

```bash
NODE_ENV=development
```

This provides more detailed error messages and disables SSL requirements.

## 🔄 Development Workflow

1. **Make Changes**: Edit `index.js`
2. **Test Locally**: Use ngrok to expose local server
3. **Test Webhook**: Create test events in GitHub
4. **Deploy**: Push to repository to trigger Render deployment

### Local Testing with ngrok

```bash
# Install ngrok
npm install -g ngrok

# Start service locally
npm run dev

# In another terminal, expose local server
ngrok http 3000

# Use ngrok URL for GitHub webhook
```

## 📈 Next Steps

Once the ingestion service is running:

1. **Verify Events**: Check that GitHub events are being received and stored
2. **Build API Service**: Create the FastAPI service to process stored events
3. **Add AI Integration**: Connect Gemini API for PR insights
4. **Connect Flutter**: Integrate real-time data with Flutter app

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is part of the FlowLens hackathon project.

---

**FlowLens** - AI-Powered DevOps Workflow Visualization 🚀
