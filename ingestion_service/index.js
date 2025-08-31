const express = require("express");
const bodyParser = require("body-parser");
const crypto = require("crypto");
const { Pool } = require("pg");

const app = express();
const PORT = process.env.PORT || 3000;

// Database configuration
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl:
    process.env.NODE_ENV === "production"
      ? { rejectUnauthorized: false }
      : false,
});

// Middleware
app.use(bodyParser.json({ limit: "50mb" })); // GitHub payloads can be large
app.use(bodyParser.urlencoded({ extended: true }));

// Webhook secret for security
const WEBHOOK_SECRET = process.env.GITHUB_WEBHOOK_SECRET;

// Verify GitHub webhook signature
function verifyGitHubSignature(payload, signature) {
  if (!WEBHOOK_SECRET) {
    console.warn(
      "⚠️  GITHUB_WEBHOOK_SECRET not set - webhook signatures will not be verified"
    );
    return true; // Allow for development
  }

  const expectedSignature = crypto
    .createHmac("sha256", WEBHOOK_SECRET)
    .update(payload, "utf8")
    .digest("hex");

  const trusted = Buffer.from(`sha256=${expectedSignature}`, "ascii");
  const untrusted = Buffer.from(signature, "ascii");

  return crypto.timingSafeEqual(trusted, untrusted);
}

// Health check endpoint
app.get("/health", (req, res) => {
  res.json({
    status: "healthy",
    service: "FlowLens Ingestion Service",
    timestamp: new Date().toISOString(),
  });
});

// Root endpoint
app.get("/", (req, res) => {
  res.json({
    service: "FlowLens Ingestion Service",
    description:
      "GitHub webhook processor for AI-powered DevOps workflow visualization",
    endpoints: {
      health: "/health",
      webhook: "/webhook (POST)",
      events: "/events (GET)",
    },
  });
});

// Main webhook endpoint
app.post("/webhook", async (req, res) => {
  const signature = req.get("X-Hub-Signature-256");
  const eventType = req.get("X-GitHub-Event");
  const deliveryId = req.get("X-GitHub-Delivery");

  console.log(`📥 Received ${eventType} event (delivery: ${deliveryId})`);

  // Verify signature
  if (!verifyGitHubSignature(JSON.stringify(req.body), signature)) {
    console.error("❌ Invalid webhook signature");
    return res.status(401).json({ error: "Invalid signature" });
  }

  try {
    // Insert raw event into database
    const eventId = await insertRawEvent(eventType, req.body, deliveryId);

    // Process specific events for FlowLens
    await processEvent(eventType, req.body, eventId);

    console.log(
      `✅ Successfully processed ${eventType} event (ID: ${eventId})`
    );
    res.status(200).json({
      success: true,
      eventId,
      eventType,
      message: "Event processed successfully",
    });
  } catch (error) {
    console.error("❌ Error processing webhook:", error);
    res.status(500).json({
      error: "Internal server error",
      details:
        process.env.NODE_ENV === "development" ? error.message : undefined,
    });
  }
});

// Get recent events (for debugging)
app.get("/events", async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 20;
    const result = await pool.query(
      "SELECT id, event_type, processed, received_at FROM raw_events ORDER BY received_at DESC LIMIT $1",
      [limit]
    );

    res.json({
      events: result.rows,
      total: result.rows.length,
    });
  } catch (error) {
    console.error("❌ Error fetching events:", error);
    res.status(500).json({ error: "Failed to fetch events" });
  }
});

// Insert raw event into database
async function insertRawEvent(eventType, payload, deliveryId) {
  const query = `
    INSERT INTO raw_events (event_type, payload, delivery_id, processed, received_at)
    VALUES ($1, $2, $3, $4, NOW())
    RETURNING id
  `;

  const result = await pool.query(query, [
    eventType,
    JSON.stringify(payload),
    deliveryId,
    false,
  ]);

  return result.rows[0].id;
}

// Process events for FlowLens workflow tracking
async function processEvent(eventType, payload, eventId) {
  console.log(`🔄 Processing ${eventType} event...`);

  switch (eventType) {
    case "pull_request":
      await processPullRequestEvent(payload, eventId);
      break;

    case "workflow_run":
      await processWorkflowRunEvent(payload, eventId);
      break;

    case "check_run":
      await processCheckRunEvent(payload, eventId);
      break;

    case "check_suite":
      await processCheckSuiteEvent(payload, eventId);
      break;

    case "pull_request_review":
      await processPullRequestReviewEvent(payload, eventId);
      break;

    case "push":
      await processPushEvent(payload, eventId);
      break;

    case "ping":
      console.log("🏓 Ping event received - webhook is working!");
      break;

    default:
      console.log(`ℹ️  Event type ${eventType} - stored but not processed`);
  }

  // Mark event as processed
  await pool.query("UPDATE raw_events SET processed = $1 WHERE id = $2", [
    true,
    eventId,
  ]);
}

// Process pull request events
async function processPullRequestEvent(payload, eventId) {
  const { action, pull_request, repository } = payload;

  console.log(`📋 PR #${pull_request.number} - ${action}`);

  if (
    action === "opened" ||
    action === "reopened" ||
    action === "synchronize"
  ) {
    // Extract PR data
    const prData = {
      pr_number: pull_request.number,
      title: pull_request.title,
      description: pull_request.body || "",
      author: pull_request.user.login,
      author_avatar: pull_request.user.avatar_url,
      commit_sha: pull_request.head.sha,
      repository_name: repository.full_name,
      branch_name: pull_request.head.ref,
      files_changed: [], // Will be populated by API service
      additions: pull_request.additions || 0,
      deletions: pull_request.deletions || 0,
      is_draft: pull_request.draft || false,
    };

    // Upsert pull request data
    await upsertPullRequest(prData);

    // Initialize or update pipeline status
    await upsertPipelineRun(pull_request.number, {
      commit_sha: pull_request.head.sha,
      author: pull_request.user.login,
      author_avatar: pull_request.user.avatar_url,
      status_pr: action === "opened" ? "opened" : "updated",
    });
  }

  if (action === "closed" && pull_request.merged) {
    // PR was merged
    await updatePipelineStatus(pull_request.number, "status_merge", "merged");
  }
}

// Process workflow run events (CI/CD builds)
async function processWorkflowRunEvent(payload, eventId) {
  const { action, workflow_run } = payload;

  console.log(
    `🔧 Workflow "${workflow_run.name}" - ${action} (${
      workflow_run.conclusion || workflow_run.status
    })`
  );

  // Find associated PR
  const prNumbers = workflow_run.pull_requests?.map((pr) => pr.number) || [];

  for (const prNumber of prNumbers) {
    if (action === "requested" || action === "in_progress") {
      await updatePipelineStatus(prNumber, "status_build", "running");
    } else if (action === "completed") {
      const status =
        workflow_run.conclusion === "success" ? "passed" : "failed";
      await updatePipelineStatus(prNumber, "status_build", status);
    }
  }
}

// Process check run events
async function processCheckRunEvent(payload, eventId) {
  const { action, check_run } = payload;

  console.log(
    `✅ Check run "${check_run.name}" - ${action} (${
      check_run.conclusion || check_run.status
    })`
  );

  // Find associated PR
  const prNumbers = check_run.pull_requests?.map((pr) => pr.number) || [];

  for (const prNumber of prNumbers) {
    if (action === "created" || action === "rerequested") {
      await updatePipelineStatus(prNumber, "status_build", "running");
    } else if (action === "completed") {
      const status = check_run.conclusion === "success" ? "passed" : "failed";
      await updatePipelineStatus(prNumber, "status_build", status);
    }
  }
}

// Process check suite events
async function processCheckSuiteEvent(payload, eventId) {
  const { action, check_suite } = payload;

  console.log(
    `📦 Check suite - ${action} (${
      check_suite.conclusion || check_suite.status
    })`
  );

  // Find associated PR
  const prNumbers = check_suite.pull_requests?.map((pr) => pr.number) || [];

  for (const prNumber of prNumbers) {
    if (action === "requested" || action === "rerequested") {
      await updatePipelineStatus(prNumber, "status_build", "running");
    } else if (action === "completed") {
      const status = check_suite.conclusion === "success" ? "passed" : "failed";
      await updatePipelineStatus(prNumber, "status_build", status);
    }
  }
}

// Process pull request review events
async function processPullRequestReviewEvent(payload, eventId) {
  const { action, review, pull_request } = payload;

  console.log(
    `👀 PR #${pull_request.number} review - ${action} (${review.state})`
  );

  if (action === "submitted") {
    if (review.state === "approved") {
      await updatePipelineStatus(
        pull_request.number,
        "status_approval",
        "approved"
      );
    } else if (review.state === "changes_requested") {
      await updatePipelineStatus(
        pull_request.number,
        "status_approval",
        "changes_requested"
      );
    }
  }
}

// Process push events
async function processPushEvent(payload, eventId) {
  const { ref, repository, commits } = payload;

  console.log(`📤 Push to ${ref} with ${commits.length} commits`);

  // For pushes to main/master that might affect PRs
  if (ref === "refs/heads/main" || ref === "refs/heads/master") {
    console.log("ℹ️  Push to main branch - may trigger PR updates");
  }
}

// Database helper functions
async function upsertPullRequest(prData) {
  const query = `
    INSERT INTO pull_requests_view (
      pr_number, title, description, author, author_avatar, commit_sha,
      repository_name, branch_name, files_changed, additions, deletions, is_draft,
      created_at, updated_at
    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, NOW(), NOW())
    ON CONFLICT (pr_number) 
    DO UPDATE SET
      title = EXCLUDED.title,
      description = EXCLUDED.description,
      commit_sha = EXCLUDED.commit_sha,
      additions = EXCLUDED.additions,
      deletions = EXCLUDED.deletions,
      is_draft = EXCLUDED.is_draft,
      updated_at = NOW()
  `;

  await pool.query(query, [
    prData.pr_number,
    prData.title,
    prData.description,
    prData.author,
    prData.author_avatar,
    prData.commit_sha,
    prData.repository_name,
    prData.branch_name,
    JSON.stringify(prData.files_changed),
    prData.additions,
    prData.deletions,
    prData.is_draft,
  ]);
}

async function upsertPipelineRun(prNumber, data) {
  const query = `
    INSERT INTO pipeline_runs (
      pr_number, commit_sha, author, avatar_url, updated_at
    ) VALUES ($1, $2, $3, $4, NOW())
    ON CONFLICT (pr_number)
    DO UPDATE SET
      commit_sha = EXCLUDED.commit_sha,
      author = EXCLUDED.author,
      avatar_url = EXCLUDED.avatar_url,
      updated_at = NOW()
  `;

  await pool.query(query, [
    prNumber,
    data.commit_sha,
    data.author,
    data.author_avatar,
  ]);

  // Update PR status if provided
  if (data.status_pr) {
    await updatePipelineStatus(prNumber, "status_pr", data.status_pr);
  }
}

async function updatePipelineStatus(prNumber, statusField, statusValue) {
  const query = `
    UPDATE pipeline_runs 
    SET ${statusField} = $1, updated_at = NOW()
    WHERE pr_number = $2
  `;

  await pool.query(query, [statusValue, prNumber]);
  console.log(`📊 Updated PR #${prNumber}: ${statusField} = ${statusValue}`);
}

// Graceful shutdown
process.on("SIGTERM", async () => {
  console.log("🛑 Received SIGTERM, shutting down gracefully...");
  await pool.end();
  process.exit(0);
});

process.on("SIGINT", async () => {
  console.log("🛑 Received SIGINT, shutting down gracefully...");
  await pool.end();
  process.exit(0);
});

// Error handling
process.on("uncaughtException", (error) => {
  console.error("❌ Uncaught Exception:", error);
  process.exit(1);
});

process.on("unhandledRejection", (reason, promise) => {
  console.error("❌ Unhandled Rejection at:", promise, "reason:", reason);
  process.exit(1);
});

// Start server
app.listen(PORT, () => {
  console.log(`🚀 FlowLens Ingestion Service running on port ${PORT}`);
  console.log(`📡 Webhook endpoint: http://localhost:${PORT}/webhook`);
  console.log(`🏥 Health check: http://localhost:${PORT}/health`);

  // Test database connection
  pool.query("SELECT NOW()", (err, result) => {
    if (err) {
      console.error("❌ Database connection failed:", err.message);
    } else {
      console.log("✅ Database connected successfully");
    }
  });
});
