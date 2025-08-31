# YugabyteDB Setup Guide for FlowLens

This guide will walk you through setting up YugabyteDB Cloud for the FlowLens ingestion service.

## 🌟 Why YugabyteDB?

- **PostgreSQL Compatible**: Uses standard SQL with JSON support
- **Free Tier**: Generous free sandbox cluster
- **Global Distribution**: Built for cloud-native applications
- **High Performance**: Designed for modern applications

## 🚀 Step-by-Step Setup

### 1. Create YugabyteDB Cloud Account

1. Go to **[YugabyteDB Cloud](https://cloud.yugabyte.com/)**
2. Click **"Sign up for free"**
3. Use your GitHub account for quick signup
4. Verify your email address

### 2. Create a Sandbox Cluster

1. **Click "Create Cluster"**
2. **Select "Sandbox"** (Free tier)
3. **Choose region** closest to your location (e.g., us-west-2)
4. **Name your cluster**: `flowlens-sandbox`
5. **Click "Create Cluster"**

⏱️ _Cluster creation takes 2-3 minutes_

### 3. Get Connection Details

Once your cluster is ready:

1. **Click "Connect"** on your cluster
2. **Copy the connection string** - it looks like:
   ```
   postgresql://admin:password@12345-demo.aws.ybdb.io:5433/yugabyte?ssl=true
   ```
3. **Save this URL** - you'll need it for the `DATABASE_URL` environment variable

### 4. Create Database Tables

#### Option A: Using YugabyteDB Web Console

1. Click **"Connect"** → **"Launch Cloud Shell"**
2. Copy and paste the schema from below
3. Press Enter to execute

#### Option B: Using Local Client

```bash
# Install PostgreSQL client (if not already installed)
# On Windows: Download from postgresql.org
# On macOS: brew install postgresql
# On Ubuntu: sudo apt-get install postgresql-client

# Connect to your cluster
psql "postgresql://admin:password@your-host.aws.ybdb.io:5433/yugabyte?ssl=true"
```

### 5. Database Schema

Copy and paste this SQL to create the required tables:

```sql
-- Raw GitHub events storage
CREATE TABLE raw_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type TEXT NOT NULL,          -- "pull_request", "workflow_run", etc.
  payload JSONB NOT NULL,            -- Raw GitHub webhook payload
  delivery_id TEXT,                  -- GitHub delivery ID for deduplication
  processed BOOLEAN DEFAULT FALSE,   -- Flag for AI service processing
  received_at TIMESTAMPTZ DEFAULT now()
);

-- Create index for faster queries
CREATE INDEX idx_raw_events_processed ON raw_events(processed);
CREATE INDEX idx_raw_events_event_type ON raw_events(event_type);
CREATE INDEX idx_raw_events_received_at ON raw_events(received_at DESC);

-- Pull request data for Flutter app convenience
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

-- Pipeline status tracking for workflow visualization
CREATE TABLE pipeline_runs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pr_number INT UNIQUE NOT NULL,     -- One pipeline per PR
  commit_sha TEXT,
  author TEXT,
  avatar_url TEXT,
  status_pr TEXT DEFAULT 'pending',       -- PR Created stage
  status_build TEXT DEFAULT 'pending',    -- Build Started/Completed stage
  status_approval TEXT DEFAULT 'pending', -- Approval stage
  status_merge TEXT DEFAULT 'pending',    -- Merged stage
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Create foreign key relationship
ALTER TABLE pipeline_runs
ADD CONSTRAINT fk_pipeline_pr
FOREIGN KEY (pr_number) REFERENCES pull_requests_view(pr_number)
ON DELETE CASCADE;

-- AI Insights table (will be populated by API service)
CREATE TABLE insights (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pr_number INT NOT NULL,
  commit_sha TEXT,
  author TEXT,
  avatar_url TEXT,
  risk_level TEXT,                   -- "low", "medium", "high"
  summary TEXT,                      -- One-line description from Gemini
  recommendation TEXT,               -- Suggested action from Gemini
  created_at TIMESTAMPTZ DEFAULT now(),

  FOREIGN KEY (pr_number) REFERENCES pull_requests_view(pr_number)
);

-- Indexes for better performance
CREATE INDEX idx_insights_pr_number ON insights(pr_number);
CREATE INDEX idx_pipeline_runs_pr_number ON pipeline_runs(pr_number);
CREATE INDEX idx_pipeline_runs_updated_at ON pipeline_runs(updated_at DESC);
```

### 6. Verify Setup

Run this test query to confirm everything is working:

```sql
-- Test the tables
SELECT 'raw_events' as table_name, count(*) as row_count FROM raw_events
UNION ALL
SELECT 'pull_requests_view', count(*) FROM pull_requests_view
UNION ALL
SELECT 'pipeline_runs', count(*) FROM pipeline_runs
UNION ALL
SELECT 'insights', count(*) FROM insights;
```

You should see:

```
   table_name     | row_count
------------------+-----------
 raw_events       |         0
 pull_requests_view |         0
 pipeline_runs    |         0
 insights         |         0
```

### 7. Connection Security

YugabyteDB Cloud uses SSL by default. Your connection string includes `?ssl=true` - keep this for security.

#### IP Allowlist (Optional)

For production, you may want to restrict access:

1. Go to your cluster **Settings**
2. Click **"Network Access"**
3. Add your deployment IP (Render will provide this)

### 8. Environment Variable

Add your connection string to your ingestion service `.env` file:

```bash
DATABASE_URL=postgresql://admin:your_password@your_host.aws.ybdb.io:5433/yugabyte?ssl=true
```

## 🔧 Testing the Connection

Create a simple test file to verify your connection:

```javascript
// test-db.js
const { Pool } = require("pg");

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
});

async function testConnection() {
  try {
    const result = await pool.query("SELECT NOW() as current_time");
    console.log("✅ Database connected successfully!");
    console.log("Current time:", result.rows[0].current_time);

    // Test tables exist
    const tables = await pool.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public'
    `);

    console.log(
      "📋 Available tables:",
      tables.rows.map((r) => r.table_name)
    );
  } catch (error) {
    console.error("❌ Database connection failed:", error.message);
  } finally {
    await pool.end();
  }
}

testConnection();
```

Run with:

```bash
node test-db.js
```

## 🎯 Sample Data (Optional)

For testing, you can insert sample data:

```sql
-- Sample PR data
INSERT INTO pull_requests_view (
  pr_number, title, description, author, author_avatar, commit_sha,
  repository_name, branch_name, additions, deletions
) VALUES (
  1,
  'Add AI-powered workflow visualization',
  'Implementing FlowLens dashboard with real-time PR tracking',
  'dev-user',
  'https://github.com/dev-user.png',
  'abc123def456',
  'DevOps-Malayalam/mission-control',
  'feature/ai-dashboard',
  150,
  20
);

-- Sample pipeline status
INSERT INTO pipeline_runs (
  pr_number, commit_sha, author, avatar_url,
  status_pr, status_build, status_approval, status_merge
) VALUES (
  1,
  'abc123def456',
  'dev-user',
  'https://github.com/dev-user.png',
  'opened',
  'running',
  'pending',
  'pending'
);

-- Sample AI insight
INSERT INTO insights (
  pr_number, commit_sha, author, avatar_url,
  risk_level, summary, recommendation
) VALUES (
  1,
  'abc123def456',
  'dev-user',
  'https://github.com/dev-user.png',
  'medium',
  'Large feature addition with UI changes',
  'Request code review from senior developer'
);
```

## 📊 Monitoring

YugabyteDB Cloud provides:

- **Performance metrics** in the dashboard
- **Query monitoring**
- **Alerts** for issues
- **Backup automation**

## 🔄 Next Steps

1. ✅ Database is set up
2. 🔜 Configure ingestion service with `DATABASE_URL`
3. 🔜 Test webhook processing
4. 🔜 Build API service to process insights
5. 🔜 Connect Flutter app

## 🆘 Troubleshooting

### Connection Issues

**SSL Certificate Error:**

```bash
# Add to connection string
&sslmode=require&sslcert=path/to/cert
```

**Timeout Issues:**

- Check your internet connection
- Verify the host URL is correct
- Ensure the cluster is running (not paused)

**Authentication Failed:**

- Double-check username/password
- Verify the database name (usually 'yugabyte')

### Performance Tips

- Use connection pooling (already configured in ingestion service)
- Create indexes for frequently queried columns
- Monitor query performance in YugabyteDB dashboard

---

🎉 **Your YugabyteDB is now ready for FlowLens!**
