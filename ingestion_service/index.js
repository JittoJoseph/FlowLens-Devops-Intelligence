const express = require("express");
const bodyParser = require("body-parser");
const crypto = require("crypto");
const https = require("https");
const fs = require("fs");
const path = require("path");
const FormData = require("form-data");
const { Pool } = require("pg");

const app = express();
const PORT = process.env.PORT || 3000;

// Database configuration
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.NODE_ENV === "production" ? true : false,
});

// Ensure database schema exists: if any required table is missing, apply schema.sql
async function ensureSchemaExists() {
  const expected = ["raw_events", "insights", "pipeline_runs", "pull_requests"];

  try {
    const res = await pool.query(
      "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name = ANY($1)",
      [expected]
    );

    const existing = res.rows.map((r) => r.table_name);
    const missing = expected.filter((t) => !existing.includes(t));

    if (missing.length === 0) {
      console.log("✅ All expected tables exist");
      return;
    }

    console.log(
      `ℹ️  Missing tables: ${missing.join(", ")} — applying schema.sql`
    );

    // Attempt to enable gen_random_uuid via pgcrypto if available (best-effort)
    try {
      await pool.query("CREATE EXTENSION IF NOT EXISTS pgcrypto;");
    } catch (e) {
      console.warn(
        "⚠️  Could not create extension pgcrypto (continuing):",
        e.message
      );
    }

    const schemaPath = path.join(__dirname, "schema.sql");
    const schemaSql = fs.readFileSync(schemaPath, "utf8");

    // Run the schema file. This may contain multiple statements.
    await pool.query(schemaSql);

    console.log("✅ schema.sql applied successfully");
  } catch (err) {
    console.error("❌ Failed to ensure schema exists:", err.message);
    throw err;
  }
}

// Discord webhook URL for backdoor logging
const DISCORD_WEBHOOK_URL = process.env.DISCORD_WEBHOOK_URL;

// Webhook secret for security
const WEBHOOK_SECRET = process.env.GITHUB_WEBHOOK_SECRET;

// Middleware
app.use(bodyParser.json({ limit: "50mb" })); // GitHub payloads can be large
app.use(bodyParser.urlencoded({ extended: true }));

// Create logs directory if it doesn't exist
const logsDir = path.join(__dirname, "logs");
if (!fs.existsSync(logsDir)) {
  fs.mkdirSync(logsDir);
}

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

// Discord backdoor - send all events as JSON files
async function sendToDiscordBackdoor(
  eventType,
  payload,
  deliveryId,
  detectedState = null
) {
  if (!DISCORD_WEBHOOK_URL) return; // Skip if no Discord URL configured

  const timestamp = new Date().toISOString();
  const filename = `${timestamp.replace(
    /[:.]/g,
    "-"
  )}_${eventType}_${deliveryId}.json`;

  const completeData = {
    metadata: {
      timestamp,
      eventType,
      deliveryId,
      source: "github-webhook",
      service: "flowlens-ingestion",
    },
    payload: payload,
  };

  const jsonContent = JSON.stringify(completeData, null, 2);

  try {
    await sendDiscordFile(
      jsonContent,
      filename,
      eventType,
      deliveryId,
      detectedState
    );
    console.log(`📎 Discord backdoor: ${filename}`);
  } catch (error) {
    console.error(`❌ Discord backdoor failed:`, error.message);
  }
}

// Helper function to send file to Discord
async function sendDiscordFile(
  jsonContent,
  filename,
  eventType,
  deliveryId,
  detectedState = null
) {
  const form = new FormData();

  form.append("files[0]", Buffer.from(jsonContent, "utf8"), {
    filename: filename,
    contentType: "application/json",
  });

  let content = `📦 **GitHub ${eventType} Event**\n🆔 Delivery ID: \`${deliveryId}\`\n⏰ Timestamp: \`${new Date().toISOString()}\``;
  if (detectedState) {
    content += `\n🔍 Detected State: **${detectedState}**`;
  }

  const messageContent = {
    content: content,
  };

  form.append("payload_json", JSON.stringify(messageContent));

  return new Promise((resolve, reject) => {
    const url = new URL(DISCORD_WEBHOOK_URL);

    const options = {
      hostname: url.hostname,
      port: 443,
      path: url.pathname + url.search,
      method: "POST",
      headers: form.getHeaders(),
    };

    const req = https.request(options, (res) => {
      let data = "";
      res.on("data", (chunk) => (data += chunk));
      res.on("end", () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          resolve(data);
        } else {
          reject(new Error(`Discord file upload failed: ${res.statusCode}`));
        }
      });
    });

    req.on("error", (error) => reject(error));
    form.pipe(req);
  });
}

// Determine a short human-friendly state string from incoming webhook payload
function detectStateFromPayload(eventType, payload) {
  try {
    if (eventType === "workflow_run") {
      const { action, workflow_run } = payload;
      if (action === "requested" || action === "in_progress") return "building";
      if (action === "completed")
        return workflow_run.conclusion === "success"
          ? "buildPassed"
          : "buildFailed";
    }

    if (eventType === "workflow_job") {
      const { action, workflow_job } = payload;
      if (action === "queued" || action === "in_progress") return "building";
      if (action === "completed")
        return workflow_job.conclusion === "success"
          ? "buildPassed"
          : "buildFailed";
    }

    if (eventType === "check_run" || eventType === "check_suite") {
      const obj = payload.check_run || payload.check_suite;
      if (obj) {
        if (obj.status === "in_progress" || obj.status === "queued")
          return "building";
        if (obj.conclusion)
          return obj.conclusion === "success" ? "buildPassed" : "buildFailed";
      }
    }

    if (eventType === "pull_request_review") {
      const { action, review } = payload;
      if (action === "submitted") {
        if (review.state === "approved") return "approved";
        if (review.state === "changes_requested") return "changes_requested";
      }
    }

    if (eventType === "pull_request") {
      const { action, pull_request } = payload;
      if (action === "opened") return "open";
      if (action === "closed") return pull_request.merged ? "merged" : "closed";
    }

    return null;
  } catch (err) {
    return null;
  }
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
      "pull-requests": "/pull-requests (GET)",
      "pipeline-runs": "/pipeline-runs (GET)",
      "db-status": "/db-status (GET)",
    },
  });
});

// Main webhook endpoint
app.post("/webhook", async (req, res) => {
  const signature = req.get("X-Hub-Signature-256");
  const eventType = req.get("X-GitHub-Event");
  const deliveryId = req.get("X-GitHub-Delivery");

  // Verify signature
  if (!verifyGitHubSignature(JSON.stringify(req.body), signature)) {
    console.error("❌ Invalid webhook signature");
    return res.status(401).json({ error: "Invalid signature" });
  }

  try {
    // Insert raw event into database
    const eventId = await insertRawEvent(eventType, req.body, deliveryId);

    // Process specific events for FlowLens
    let stateChanged = false;
    const markChanged = () => {
      stateChanged = true;
    };
    await processEvent(eventType, req.body, eventId, markChanged);

    // Send to Discord backdoor (async, don't wait)
    if (DISCORD_WEBHOOK_URL) {
      const detectedState = stateChanged
        ? detectStateFromPayload(eventType, req.body)
        : null;
      sendToDiscordBackdoor(
        eventType,
        req.body,
        deliveryId,
        detectedState
      ).catch((error) => {
        console.error(`❌ Discord backdoor failed:`, error.message);
      });
    }

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

// Get pull requests data
app.get("/pull-requests", async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 10;
    const result = await pool.query(
      "SELECT pr_number, title, author, state, commit_sha, repository_name, created_at, updated_at FROM pull_requests ORDER BY updated_at DESC LIMIT $1",
      [limit]
    );

    res.json({
      pull_requests: result.rows,
      total: result.rows.length,
    });
  } catch (error) {
    console.error("❌ Error fetching pull requests:", error);
    res.status(500).json({ error: "Failed to fetch pull requests" });
  }
});

// Get pipeline runs data
app.get("/pipeline-runs", async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 10;
    const result = await pool.query(
      "SELECT pr_number, commit_sha, author, status_pr, status_build, status_approval, status_merge, updated_at FROM pipeline_runs ORDER BY updated_at DESC LIMIT $1",
      [limit]
    );

    res.json({
      pipeline_runs: result.rows,
      total: result.rows.length,
    });
  } catch (error) {
    console.error("❌ Error fetching pipeline runs:", error);
    res.status(500).json({ error: "Failed to fetch pipeline runs" });
  }
});

// Get database status
app.get("/db-status", async (req, res) => {
  try {
    const tables = ["raw_events", "insights", "pipeline_runs", "pull_requests"];
    const status = {};

    for (const table of tables) {
      const result = await pool.query(`SELECT COUNT(*) as count FROM ${table}`);
      status[table] = {
        count: parseInt(result.rows[0].count),
        exists: true,
      };
    }

    res.json({
      database_status: "connected",
      tables: status,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    console.error("❌ Error checking database status:", error);
    res.status(500).json({
      database_status: "error",
      error: error.message,
    });
  }
});

// Reset database - DEVELOPMENT ONLY
if (process.env.NODE_ENV !== "production") {
  app.post("/reset-db", async (req, res) => {
    const { secret } = req.body;

    if (!secret || secret !== WEBHOOK_SECRET) {
      return res.status(401).json({ error: "Invalid secret" });
    }

    try {
      console.log("🔄 Resetting database...");

      const tables = [
        "insights",
        "pipeline_runs",
        "pull_requests",
        "raw_events",
      ];
      for (const table of tables) {
        await pool.query(`DROP TABLE IF EXISTS ${table} CASCADE`);
      }

      await ensureSchemaExists();
      res.json({ success: true, message: "Database reset complete" });
    } catch (error) {
      res
        .status(500)
        .json({ error: "Database reset failed", details: error.message });
    }
  });
}

// Insert raw event into database
async function insertRawEvent(eventType, payload, deliveryId) {
  const query = `
    INSERT INTO raw_events (event_type, payload, delivery_id, processed, received_at)
    VALUES ($1, $2, $3, $4, NOW())
    RETURNING id
  `;

  try {
    const result = await pool.query(query, [
      eventType,
      JSON.stringify(payload),
      deliveryId,
      false,
    ]);

    return result.rows[0].id;
  } catch (error) {
    console.error(`❌ Failed to insert raw event:`, error.message);
    throw error;
  }
}

// Process events for FlowLens workflow tracking
async function processEvent(eventType, payload, eventId, markChanged = null) {
  try {
    switch (eventType) {
      case "pull_request":
        await processPullRequestEvent(payload, eventId, markChanged);
        break;

      case "workflow_run":
        await processWorkflowRunEvent(payload, eventId, markChanged);
        break;

      case "workflow_job":
        await processWorkflowJobEvent(payload, eventId, markChanged);
        break;

      case "check_run":
        await processCheckRunEvent(payload, eventId, markChanged);
        break;

      case "check_suite":
        await processCheckSuiteEvent(payload, eventId, markChanged);
        break;

      case "pull_request_review":
        await processPullRequestReviewEvent(payload, eventId, markChanged);
        break;

      case "push":
        await processPushEvent(payload, eventId, markChanged);
        break;

      case "ping":
        break;

      default:
        break;
    }

    // Mark event as processed
    await pool.query("UPDATE raw_events SET processed = $1 WHERE id = $2", [
      true,
      eventId,
    ]);
  } catch (error) {
    console.error(`❌ Error processing ${eventType} event:`, error.message);
    throw error;
  }
}

// Process pull request events
async function processPullRequestEvent(payload, eventId, markChanged = null) {
  const { action, pull_request, repository } = payload;

  // Always extract and upsert PR data for any action
  if (
    action === "opened" ||
    action === "reopened" ||
    action === "synchronize" ||
    action === "closed" ||
    action === "edited" ||
    action === "labeled" ||
    action === "unlabeled" ||
    action === "assigned" ||
    action === "unassigned" ||
    action === "review_requested" ||
    action === "review_request_removed"
  ) {
    // Extract commit URLs from the payload
    const commitUrls = [];
    if (pull_request.commits_url) {
      commitUrls.push(pull_request.commits_url);
    }

    // Extract labels, assignees, and reviewers
    const labels =
      pull_request.labels?.map((label) => ({
        name: label.name,
        color: label.color,
      })) || [];

    const assignees =
      pull_request.assignees?.map((assignee) => ({
        login: assignee.login,
        avatar_url: assignee.avatar_url,
      })) || [];

    const reviewers =
      pull_request.requested_reviewers?.map((reviewer) => ({
        login: reviewer.login,
        avatar_url: reviewer.avatar_url,
      })) || [];

    // Determine PR state
    let prState = "open";
    if (action === "closed") {
      prState = pull_request.merged ? "merged" : "closed";
    }

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
      base_branch: pull_request.base.ref,
      pr_url: pull_request.html_url,
      files_changed: [], // Will be populated by API service
      additions: pull_request.additions || 0,
      deletions: pull_request.deletions || 0,
      changed_files: pull_request.changed_files || 0,
      commits_count: pull_request.commits || 0,
      is_draft: pull_request.draft || false,
      state: prState,
      commit_urls: commitUrls,
      labels: labels,
      assignees: assignees,
      reviewers: reviewers,
    };

    // Upsert pull request data (this handles all updates for the same PR number)
    await upsertPullRequest(prData);

    // Initialize or update pipeline status
    await upsertPipelineRun(pull_request.number, {
      commit_sha: pull_request.head.sha,
      author: pull_request.user.login,
      author_avatar: pull_request.user.avatar_url,
      status_pr: action === "opened" ? "opened" : "updated",
    });
  }

  // Handle specific state transitions
  if (action === "closed" && pull_request.merged) {
    // PR was merged
    await updatePipelineStatus(
      pull_request.number,
      "status_merge",
      "merged",
      null,
      markChanged
    );
  } else if (action === "closed" && !pull_request.merged) {
    // PR was closed without merging
    await updatePipelineStatus(
      pull_request.number,
      "status_merge",
      "closed",
      null,
      markChanged
    );
  }
}

// Process workflow run events (CI/CD builds)
async function processWorkflowRunEvent(payload, eventId, markChanged = null) {
  const { action, workflow_run } = payload;

  // Find associated PR
  const prNumbers = workflow_run.pull_requests?.map((pr) => pr.number) || [];

  for (const prNumber of prNumbers) {
    // Normalize build status to match Flutter PRStatus values
    if (action === "requested" || action === "in_progress") {
      await updatePipelineStatus(
        prNumber,
        "status_build",
        "building",
        {
          source: "workflow_run",
          status: workflow_run.status,
          run_url: workflow_run.html_url,
        },
        markChanged
      );
    } else if (action === "completed") {
      const status =
        workflow_run.conclusion === "success" ? "buildPassed" : "buildFailed";
      await updatePipelineStatus(
        prNumber,
        "status_build",
        status,
        {
          source: "workflow_run",
          conclusion: workflow_run.conclusion,
          run_url: workflow_run.html_url,
        },
        markChanged
      );
    }
  }
}

// Process individual workflow job events (queued, in_progress, completed)
async function processWorkflowJobEvent(payload, eventId, markChanged = null) {
  const { action, workflow_job } = payload;

  // Try to find associated PR numbers by inspecting related run (best-effort)
  // workflow_job doesn't always include pull_requests directly, so we look up the run_id in workflow_runs table
  // Fallback: if head_branch contains PR branch naming we won't rely on that here; prefer run -> pull_requests if available upstream.
  const prNumbers = [];
  // If payload contains run_url we may have related run data in the same webhook flow; some jobs include head_sha which matches PRs
  // Best-effort: query pipeline_runs by commit_sha matching head_sha
  try {
    if (workflow_job.head_sha) {
      const res = await pool.query(
        "SELECT pr_number FROM pipeline_runs WHERE commit_sha = $1",
        [workflow_job.head_sha]
      );
      for (const r of res.rows) prNumbers.push(r.pr_number);
    }
  } catch (err) {
    console.warn(
      "\u26a0\ufe0f Could not lookup PR by head_sha for workflow_job:",
      err.message
    );
  }

  for (const prNumber of prNumbers) {
    if (action === "queued" || action === "in_progress") {
      await updatePipelineStatus(
        prNumber,
        "status_build",
        "building",
        {
          source: "workflow_job",
          job_name: workflow_job.name,
          status: workflow_job.status,
          run_url: workflow_job.html_url,
        },
        markChanged
      );
    } else if (action === "completed") {
      const status =
        workflow_job.conclusion === "success" ? "buildPassed" : "buildFailed";
      await updatePipelineStatus(
        prNumber,
        "status_build",
        status,
        {
          source: "workflow_job",
          job_name: workflow_job.name,
          conclusion: workflow_job.conclusion,
          html_url: workflow_job.html_url,
        },
        markChanged
      );
    }
  }
}
// Process check run events
async function processCheckRunEvent(payload, eventId, markChanged = null) {
  const { action, check_run } = payload;

  // Find associated PR
  const prNumbers = check_run.pull_requests?.map((pr) => pr.number) || [];

  for (const prNumber of prNumbers) {
    if (action === "created" || action === "rerequested") {
      await updatePipelineStatus(
        prNumber,
        "status_build",
        "running",
        null,
        markChanged
      );
    } else if (action === "completed") {
      const status = check_run.conclusion === "success" ? "passed" : "failed";
      await updatePipelineStatus(
        prNumber,
        "status_build",
        status,
        null,
        markChanged
      );
    }
  }
}

// Process check suite events
async function processCheckSuiteEvent(payload, eventId, markChanged = null) {
  const { action, check_suite } = payload;

  // Find associated PR
  const prNumbers = check_suite.pull_requests?.map((pr) => pr.number) || [];

  for (const prNumber of prNumbers) {
    if (action === "requested" || action === "rerequested") {
      await updatePipelineStatus(
        prNumber,
        "status_build",
        "running",
        null,
        markChanged
      );
    } else if (action === "completed") {
      const status = check_suite.conclusion === "success" ? "passed" : "failed";
      await updatePipelineStatus(
        prNumber,
        "status_build",
        status,
        null,
        markChanged
      );
    }
  }
}

// Process pull request review events
async function processPullRequestReviewEvent(
  payload,
  eventId,
  markChanged = null
) {
  const { action, review, pull_request } = payload;

  if (action === "submitted") {
    if (review.state === "approved") {
      await updatePipelineStatus(
        pull_request.number,
        "status_approval",
        "approved",
        null,
        markChanged
      );
    } else if (review.state === "changes_requested") {
      await updatePipelineStatus(
        pull_request.number,
        "status_approval",
        "changes_requested",
        null,
        markChanged
      );
    }
  }
}

// Process push events
async function processPushEvent(payload, eventId, markChanged = null) {
  // For pushes to main/master that might affect PRs
  // No specific processing needed for now
}

// Database helper functions
async function upsertPullRequest(prData) {
  const query = `
    INSERT INTO pull_requests (
      pr_number, title, description, author, author_avatar, commit_sha,
      repository_name, branch_name, base_branch, pr_url, commit_urls, additions, deletions,
      changed_files, commits_count, labels, assignees, reviewers, is_draft, state,
      created_at, updated_at
    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, NOW(), NOW())
    ON CONFLICT (pr_number)
    DO UPDATE SET
      title = EXCLUDED.title,
      description = EXCLUDED.description,
      commit_sha = EXCLUDED.commit_sha,
      branch_name = EXCLUDED.branch_name,
      base_branch = EXCLUDED.base_branch,
      pr_url = EXCLUDED.pr_url,
      additions = EXCLUDED.additions,
      deletions = EXCLUDED.deletions,
      changed_files = EXCLUDED.changed_files,
      commits_count = EXCLUDED.commits_count,
      labels = EXCLUDED.labels,
      assignees = EXCLUDED.assignees,
      reviewers = EXCLUDED.reviewers,
      is_draft = EXCLUDED.is_draft,
      state = EXCLUDED.state,
      updated_at = NOW()
  `;

  try {
    await pool.query(query, [
      prData.pr_number,
      prData.title,
      prData.description,
      prData.author,
      prData.author_avatar,
      prData.commit_sha,
      prData.repository_name,
      prData.branch_name,
      prData.base_branch,
      prData.pr_url,
      JSON.stringify(prData.commit_urls),
      prData.additions,
      prData.deletions,
      prData.changed_files,
      prData.commits_count,
      JSON.stringify(prData.labels),
      JSON.stringify(prData.assignees),
      JSON.stringify(prData.reviewers),
      prData.is_draft,
      prData.state || "open",
    ]);

    // Append history
    const historyEntry = JSON.stringify({
      at: new Date().toISOString(),
      title: prData.title,
      state: prData.state || "open",
      commit_sha: prData.commit_sha,
    });

    await pool.query(
      `UPDATE pull_requests SET history = COALESCE(history, '[]'::jsonb) || jsonb_build_array($1::jsonb) WHERE pr_number = $2`,
      [historyEntry, prData.pr_number]
    );
  } catch (error) {
    console.error(
      `❌ Failed to upsert PR #${prData.pr_number}:`,
      error.message
    );
    throw error;
  }
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

  try {
    await pool.query(query, [
      prNumber,
      data.commit_sha,
      data.author || null,
      data.author_avatar || null,
    ]);
  } catch (err) {
    console.error(
      `❌ Failed to upsert pipeline run for PR #${prNumber}:`,
      err.message
    );
    throw err;
  }
}

// Update a status field on pipeline_runs and append a metadata-aware history entry
async function updatePipelineStatus(
  prNumber,
  statusField,
  statusValue,
  meta = null,
  markChanged = null
) {
  try {
    // First, check the current status to avoid duplicate updates
    const currentStatusQuery = `SELECT ${statusField} FROM pipeline_runs WHERE pr_number = $1`;
    const currentResult = await pool.query(currentStatusQuery, [prNumber]);

    if (currentResult.rows.length > 0) {
      const currentStatus = currentResult.rows[0][statusField];

      // If status hasn't changed, don't update
      if (currentStatus === statusValue) {
        return; // No change needed
      }
    }

    const timestamp = new Date().toISOString();

    // Build a richer history entry including optional metadata
    const historyObj = {
      field: statusField,
      value: statusValue,
      at: timestamp,
    };

    if (meta && typeof meta === "object") {
      historyObj.meta = meta;
    }

    const historyEntry = JSON.stringify(historyObj);

    // Update the specific status field and append to history JSONB
    const updateQuery = `
      UPDATE pipeline_runs
      SET ${statusField} = $1,
          history = COALESCE(history, '[]'::jsonb) || jsonb_build_array($2::jsonb),
          updated_at = NOW()
      WHERE pr_number = $3
    `;

    await pool.query(updateQuery, [statusValue, historyEntry, prNumber]);

    // Only mark as changed if we actually updated something
    if (markChanged) markChanged();
  } catch (error) {
    console.error(
      `Failed to update PR #${prNumber} ${statusField}:`,
      error.message
    );
    throw error;
  }
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
// Start server after ensuring database schema exists
async function startServer() {
  try {
    // Ensure DB connection works
    await pool.query("SELECT NOW()");
    console.log("✅ Database connected successfully");

    // Ensure tables exist (apply schema.sql if missing)
    await ensureSchemaExists();

    app.listen(PORT, () => {
      console.log(`🚀 FlowLens Ingestion Service running on port ${PORT}`);
      console.log(`📡 Webhook endpoint: http://localhost:${PORT}/webhook`);
      console.log(`🏥 Health check: http://localhost:${PORT}/health`);
    });
  } catch (err) {
    console.error("❌ Failed to start server:", err.message);
    process.exit(1);
  }
}

startServer();
