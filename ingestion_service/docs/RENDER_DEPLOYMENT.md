# Render Deployment Guide for FlowLens Ingestion Service

This guide will walk you through deploying the FlowLens ingestion service to Render, a modern cloud platform with generous free tiers.

## 🌟 Why Render?

- **Free Tier**: 750 hours/month of free compute
- **GitHub Integration**: Auto-deploy from GitHub
- **Built-in SSL**: HTTPS by default
- **Simple Setup**: No complex configuration
- **Real Logs**: Easy monitoring and debugging

## 🚀 Step-by-Step Deployment

### 1. Create Render Account

1. Go to **[render.com](https://render.com)**
2. Click **"Get Started for Free"**
3. Sign up with your **GitHub account** (recommended)
4. Verify your email if needed

### 2. Connect Your Repository

1. **Fork the repository** (if you haven't already):

   - Go to `https://github.com/DevOps-Malayalam/mission-control`
   - Click **Fork** to create your own copy

2. **Connect to Render**:
   - In Render dashboard, click **"New +"**
   - Select **"Web Service"**
   - Click **"Connect a repository"**
   - Authorize Render to access your GitHub repos
   - Select your forked repository

### 3. Configure Web Service

#### Basic Settings:

```
Name: flowlens-ingestion-service
Branch: main (or your working branch)
Region: Choose closest to your location (e.g., Oregon, Frankfurt)
```

#### Build Settings:

```
Runtime: Node
Build Command: cd ingestion_service && npm install
Start Command: cd ingestion_service && npm start
```

#### Instance Type:

```
Free ($0/month) - 512 MB RAM, 0.1 CPU
```

### 4. Environment Variables

Click **"Advanced"** and add these environment variables:

```bash
# Required: YugabyteDB connection
DATABASE_URL=postgresql://admin:password@your-host.aws.ybdb.io:5433/yugabyte?ssl=true

# Required: Webhook security
GITHUB_WEBHOOK_SECRET=your_generated_secret_here

# Optional: Server configuration
NODE_ENV=production
PORT=3000
```

**⚠️ Important:**

- Use your actual YugabyteDB connection string
- Use the same webhook secret you'll configure in GitHub
- Don't include quotes around the values

### 5. Deploy

1. Click **"Create Web Service"**
2. Render will start building and deploying
3. **Build time**: ~2-3 minutes
4. **First deploy**: ~5 minutes total

### 6. Verify Deployment

Once deployed, you'll get a URL like:

```
https://flowlens-ingestion-service.onrender.com
```

#### Test the Service:

**Health Check:**

```bash
curl https://your-app.onrender.com/health
```

**Expected Response:**

```json
{
  "status": "healthy",
  "service": "FlowLens Ingestion Service",
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

**Service Info:**

```bash
curl https://your-app.onrender.com/
```

## 🔧 Configure GitHub Webhook

Once deployed, update your GitHub webhook with the Render URL:

1. Go to your repository **Settings → Webhooks**
2. **Edit** your existing webhook (or create new one)
3. **Update Payload URL** to:
   ```
   https://your-app.onrender.com/webhook
   ```
4. Ensure **secret** matches your `GITHUB_WEBHOOK_SECRET`
5. **Update webhook**

## 📊 Monitoring Your Service

### Render Dashboard

**Logs**: Real-time application logs

```
🚀 FlowLens Ingestion Service running on port 3000
✅ Database connected successfully
📥 Received pull_request event (delivery: abc-123)
✅ Successfully processed pull_request event
```

**Events**: Deployment history and status

**Metrics**: CPU, memory, and response time monitoring

### Service Endpoints

**Health Check:**

```
GET https://your-app.onrender.com/health
```

**Recent Events (Debug):**

```
GET https://your-app.onrender.com/events?limit=10
```

**Service Info:**

```
GET https://your-app.onrender.com/
```

## 🔄 Auto-Deploy Setup

Render automatically deploys when you push to your connected branch:

1. **Make changes** to your code
2. **Push to GitHub**:
   ```bash
   git add .
   git commit -m "Update ingestion service"
   git push origin main
   ```
3. **Render auto-deploys** in ~2-3 minutes

### Deploy Notifications

Enable notifications in Render:

1. Go to **Settings → Notifications**
2. Add **email** or **Slack** integration
3. Get notified of successful/failed deploys

## 🛡️ Security and Best Practices

### Environment Variables

**Secure Storage**: Environment variables in Render are encrypted and not visible in logs.

**Update Variables**:

1. Go to **Settings → Environment**
2. Edit variables
3. Service auto-restarts with new values

### SSL/HTTPS

Render provides:

- ✅ **Free SSL certificates**
- ✅ **Automatic HTTPS redirect**
- ✅ **HTTP/2 support**

### Custom Domain (Optional)

To use your own domain:

1. Go to **Settings → Custom Domains**
2. Add your domain
3. Update DNS records as instructed

## 📈 Scaling and Performance

### Free Tier Limits

**Compute**: 750 hours/month (can run 24/7)
**Bandwidth**: 100 GB/month
**Build Time**: 500 minutes/month

### Performance Optimization

**Build Speed**:

```bash
# Use npm ci instead of npm install for faster builds
Build Command: cd ingestion_service && npm ci --only=production
```

**Memory Usage**:

- Node.js apps typically use 50-100MB
- Free tier provides 512MB (plenty of headroom)

### Upgrading (If Needed)

**Starter Plan** ($7/month):

- 25GB bandwidth
- Faster builds
- Priority support

## 🚨 Troubleshooting

### Common Deployment Issues

**Build Failed - Module Not Found:**

```bash
# Ensure package.json is in ingestion_service directory
Build Command: cd ingestion_service && npm install
```

**Database Connection Failed:**

```bash
# Check DATABASE_URL environment variable
# Verify YugabyteDB cluster is running
# Test connection string locally first
```

**Webhook Signature Verification Failed:**

```bash
# Ensure GITHUB_WEBHOOK_SECRET matches exactly
# Check webhook secret in GitHub settings
```

### Service Not Responding

**Check Service Status**:

1. Render dashboard shows **"Live"** status
2. Look for errors in **Logs** tab
3. Test health endpoint

**Common Fixes**:

- Restart service from Render dashboard
- Check environment variables
- Verify database connectivity

### Build Timeout

If builds take too long:

```bash
# Optimize build command
Build Command: cd ingestion_service && npm ci --only=production --silent
```

### Memory Issues

Monitor memory usage in Render dashboard:

- **Normal**: 50-150MB
- **High**: 300-400MB
- **Critical**: >450MB (may cause crashes)

## 🔄 Alternative Deployment Options

### Render vs Other Platforms

| Platform   | Free Tier  | Auto-Deploy | SSL | Ease       |
| ---------- | ---------- | ----------- | --- | ---------- |
| **Render** | 750h/month | ✅          | ✅  | ⭐⭐⭐⭐⭐ |
| Heroku     | 550h/month | ✅          | ✅  | ⭐⭐⭐⭐   |
| Railway    | $5 credit  | ✅          | ✅  | ⭐⭐⭐⭐   |
| Vercel     | Limited    | ✅          | ✅  | ⭐⭐⭐     |

### Docker Deployment (Advanced)

If you want to use Docker:

**dockerfile** (already created):

```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 3000
CMD ["npm", "start"]
```

**Render Docker Deploy**:

```bash
Build Command: docker build -t flowlens-ingestion ./ingestion_service
Start Command: docker run -p 3000:3000 flowlens-ingestion
```

## 📋 Post-Deployment Checklist

- ✅ Service is deployed and accessible
- ✅ Health check returns 200 OK
- ✅ Database connection successful
- ✅ Environment variables configured
- ✅ GitHub webhook URL updated
- ✅ Test webhook with sample PR
- ✅ Monitor logs for incoming events
- ✅ Set up deployment notifications

## 🎯 Next Steps

1. ✅ **Ingestion service deployed**
2. 🔜 **Test with GitHub events**
3. 🔜 **Build API/AI service**
4. 🔜 **Deploy API service to Render**
5. 🔜 **Connect Flutter app**

---

🎉 **Your FlowLens Ingestion Service is now live on Render!**

**Service URL**: `https://your-app.onrender.com`  
**Webhook URL**: `https://your-app.onrender.com/webhook`  
**Health Check**: `https://your-app.onrender.com/health`

Your service is now ready to receive GitHub webhooks and process PR workflow events in real-time!
