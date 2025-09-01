const express = require("express");
const bodyParser = require("body-parser");
const crypto = require("crypto");
const https = require("https");
const fs = require("fs");
const path = require("path");
const FormData = require("form-data");
const { Pool } = require("pg");

// Add fetch for Node.js compatibility
const fetch = (...args) =>
  import("node-fetch").then(({ default: fetch }) => fetch(...args));

const app = express();
const PORT = process.env.PORT || 3000;

// GitHub API token for authenticated requests
const GITHUB_TOKEN = process.env.GITHUB_TOKEN;

// Database configuration
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.NODE_ENV === "production" ? true : false,
});

// Ensure database schema exists: if any required table is missing, apply schema.sql
async function ensureSchemaExists() {
  const expected = [
    "repositories",
    "insights",
    "pipeline_runs",
    "pull_requests",
  ];

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

    // Apply triggers after schema is created
    const triggerPath = path.join(__dirname, "trigger.sql");
    if (fs.existsSync(triggerPath)) {
      const triggerSql = fs.readFileSync(triggerPath, "utf8");
      await pool.query(triggerSql);
      console.log("✅ trigger.sql applied successfully");
    }
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
    eventType,
    deliveryId,
    timestamp,
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

  const content = `📦 GitHub ${eventType} Event - ${deliveryId}`;
  const messageContent = { content };

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
    if (eventType === "pull_request") {
      const { action, pull_request } = payload;
      if (action === "opened") return "opened";
      if (action === "synchronize") return "updated";
      if (action === "closed") return pull_request.merged ? "merged" : "closed";
    }

    if (eventType === "pull_request_review") {
      const { action, review } = payload;
      if (action === "submitted") {
        if (review.state === "approved") return "approved";
        if (review.state === "changes_requested") return "changes_requested";
      }
    }

    if (eventType === "workflow_run") {
      const { action, workflow_run } = payload;
      if (action === "requested" || action === "in_progress") return "building";
      if (action === "completed") {
        return workflow_run.conclusion === "success"
          ? "buildPassed"
          : "buildFailed";
      }
    }

    if (eventType === "workflow_job") {
      const { action, workflow_job } = payload;
      if (action === "queued" || action === "in_progress") return "building";
      if (action === "completed") {
        return workflow_job.conclusion === "success"
          ? "buildPassed"
          : "buildFailed";
      }
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

// ================================
// Repository Management Functions
// ================================

// Extract repository data from GitHub webhook payload
function extractRepositoryData(repository) {
  if (!repository) return null;

  return {
    github_id: repository.id,
    name: repository.name,
    full_name: repository.full_name,
    description: repository.description || null,
    owner: repository.owner?.login,
    is_private: repository.private || false,
    default_branch: repository.default_branch || "main",
    html_url: repository.html_url,
    language: repository.language || null,
    stars: repository.stargazers_count || 0,
    forks: repository.forks_count || 0,
    last_activity: repository.pushed_at ? new Date(repository.pushed_at) : null,
    created_at: repository.created_at ? new Date(repository.created_at) : null,
  };
}

// Ensure repository exists in database, return repo_id
async function ensureRepositoryExists(repository) {
  if (!repository) {
    throw new Error("Repository object is required");
  }

  const repoData = extractRepositoryData(repository);
  if (!repoData) {
    throw new Error("Could not extract repository data from payload");
  }

  const upsertQuery = `
    INSERT INTO repositories (
      github_id, name, full_name, description, owner, is_private, default_branch,
      html_url, language, stars, forks, last_activity, created_at, updated_at
    ) VALUES (
      $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, NOW()
    )
    ON CONFLICT (github_id)
    DO UPDATE SET
      name = EXCLUDED.name,
      full_name = EXCLUDED.full_name,
      description = EXCLUDED.description,
      owner = EXCLUDED.owner,
      is_private = EXCLUDED.is_private,
      default_branch = EXCLUDED.default_branch,
      html_url = EXCLUDED.html_url,
      language = EXCLUDED.language,
      stars = EXCLUDED.stars,
      forks = EXCLUDED.forks,
      last_activity = EXCLUDED.last_activity,
      updated_at = NOW()
    RETURNING id
  `;

  try {
    const values = [
      repoData.github_id,
      repoData.name,
      repoData.full_name,
      repoData.description,
      repoData.owner,
      repoData.is_private,
      repoData.default_branch,
      repoData.html_url,
      repoData.language,
      repoData.stars,
      repoData.forks,
      repoData.last_activity,
      repoData.created_at,
    ];

    const result = await pool.query(upsertQuery, values);
    const repoId = result.rows[0].id;

    console.log(`📦 Repository ensured: ${repoData.full_name} (id: ${repoId})`);
    return repoId;
  } catch (error) {
    console.error(
      `❌ Failed to ensure repository ${repoData.full_name}:`,
      error.message
    );
    throw error;
  }
}

// ================================
// Main webhook endpoint
// ================================
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
    // Ensure repository exists in database and get repo_id
    const repository = req.body.repository;
    if (!repository) {
      console.warn("⚠️  No repository object in webhook payload");
      return res.status(400).json({ error: "No repository in payload" });
    }

    const repoId = await ensureRepositoryExists(repository);

    // Process specific events for FlowLens
    let stateChanged = false;
    const markChanged = () => {
      stateChanged = true;
    };
    await processEvent(eventType, req.body, repoId, markChanged);

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
      eventType,
      repository: repository.full_name,
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

// Get recent insights
app.get("/events", async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 20;
    const result = await pool.query(
      "SELECT pr_number, risk_level, summary, recommendation, created_at FROM insights ORDER BY created_at DESC LIMIT $1",
      [limit]
    );

    res.json({
      insights: result.rows,
      total: result.rows.length,
    });
  } catch (error) {
    console.error("❌ Error fetching insights:", error);
    res.status(500).json({ error: "Failed to fetch insights" });
  }
});

// Get recent pull requests
app.get("/pull-requests", async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 10;
    const result = await pool.query(
      "SELECT pr_number, title, author, state, commit_sha, branch_name, base_branch, is_draft, created_at, updated_at FROM pull_requests ORDER BY updated_at DESC LIMIT $1",
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

// Get pipeline runs
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
    const tables = [
      "repositories",
      "insights",
      "pipeline_runs",
      "pull_requests",
    ];
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

      // Drop all tables in the right order (handle foreign key dependencies)
      const tables = [
        "insights",
        "pipeline_runs",
        "pull_requests",
        "repositories",
      ];
      for (const table of tables) {
        await pool.query(`DROP TABLE IF EXISTS ${table} CASCADE`);
      }

      // Recreate schema and triggers
      await ensureSchemaExists();

      res.json({
        success: true,
        message: "Database reset complete - schema and triggers applied",
      });
    } catch (error) {
      console.error("❌ Database reset failed:", error.message);
      res
        .status(500)
        .json({ error: "Database reset failed", details: error.message });
    }
  });
}

// Helper function to fetch changed files from GitHub API
async function fetchChangedFiles(repositoryFullName, prNumber) {
  try {
    const url = `https://api.github.com/repos/${repositoryFullName}/pulls/${prNumber}/files`;

    const headers = {
      Accept: "application/vnd.github.v3+json",
      "User-Agent": "FlowLens-Ingestion-Service",
    };

    // Add GitHub token if available for authentication
    if (GITHUB_TOKEN) {
      headers["Authorization"] = `token ${GITHUB_TOKEN}`;
    }

    const response = await fetch(url, { headers });

    if (!response.ok) {
      console.warn(
        `⚠️ Failed to fetch files for PR #${prNumber}: ${response.status}`
      );
      return [];
    }

    const files = await response.json();

    // Enhanced processing - include patch data for detailed file changes
    return files.map((file) => ({
      filename: file.filename,
      status: file.status,
      additions: file.additions || 0,
      deletions: file.deletions || 0,
      changes: file.changes || 0,
      patch: file.patch || null, // Include the patch data for diff information
    }));
  } catch (error) {
    console.warn(`⚠️ Error fetching files for PR #${prNumber}:`, error.message);
    return [];
  }
}

// Process events for FlowLens workflow tracking
async function processEvent(eventType, payload, repoId, markChanged = null) {
  try {
    switch (eventType) {
      case "pull_request":
        await processPullRequestEvent(payload, repoId, markChanged);
        break;

      case "workflow_run":
        await processWorkflowRunEvent(payload, repoId, markChanged);
        break;

      case "pull_request_review":
        await processPullRequestReviewEvent(payload, repoId, markChanged);
        break;

      default:
        // Ignore other events
        break;
    }
  } catch (error) {
    console.error(`❌ Error processing ${eventType} event:`, error.message);
    throw error;
  }
}

// Process pull request events
async function processPullRequestEvent(payload, repoId, markChanged = null) {
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
    const labels = pull_request.labels?.map((label) => label.name) || [];
    const assignees = pull_request.assignees?.map((user) => user.login) || [];
    const reviewers =
      pull_request.requested_reviewers?.map((user) => user.login) || [];

    // Determine PR state and dates
    let prState = "open";
    let mergedAt = null;
    let closedAt = null;
    let merged = false;

    if (action === "closed") {
      merged = pull_request.merged || false;
      prState = merged ? "merged" : "closed";
      closedAt = new Date();
      if (merged && pull_request.merged_at) {
        mergedAt = new Date(pull_request.merged_at);
      }
    }

    // Fetch changed files from GitHub API
    const filesChanged = await fetchChangedFiles(
      repository.full_name,
      pull_request.number
    );

    // Extract PR data
    const prData = {
      pr_number: pull_request.number,
      title: pull_request.title,
      description: pull_request.body || "",
      author: pull_request.user.login,
      author_avatar: pull_request.user.avatar_url,
      commit_sha: pull_request.head.sha,
      branch_name: pull_request.head.ref,
      base_branch: pull_request.base.ref,
      pr_url: pull_request.html_url,
      commit_urls: commitUrls,
      files_changed: filesChanged,
      additions: pull_request.additions || 0,
      deletions: pull_request.deletions || 0,
      changed_files: pull_request.changed_files || 0,
      commits_count: pull_request.commits || 0,
      labels: labels,
      assignees: assignees,
      reviewers: reviewers,
      is_draft: pull_request.draft || false,
      state: prState,
      merged: merged,
      merged_at: mergedAt,
      closed_at: closedAt,
    };

    // Upsert pull request data (this handles all updates for the same PR number)
    await upsertPullRequest(prData, repoId);

    // Initialize or update pipeline status
    await upsertPipelineRun(repoId, pull_request.number, {
      commit_sha: pull_request.head.sha,
      author: pull_request.user.login,
      avatar_url: pull_request.user.avatar_url,
      title: pull_request.title,
      status_pr: action === "opened" ? "opened" : "updated",
    });

    // Track PR state changes in history
    if (action === "opened") {
      await updatePRStateHistory(repoId, pull_request.number, "opened", {
        action: action,
        author: pull_request.user.login,
      });
    } else if (action === "synchronize") {
      await updatePRStateHistory(repoId, pull_request.number, "updated", {
        action: action,
        new_commit: pull_request.head.sha,
      });
    }
  }

  // Handle specific state transitions
  if (action === "closed" && pull_request.merged) {
    // PR was merged
    await updatePipelineStatus(
      repoId,
      pull_request.number,
      "status_merge",
      "merged",
      {
        merged_by: pull_request.merged_by?.login,
        merge_commit_sha: pull_request.merge_commit_sha,
      },
      markChanged
    );
  } else if (action === "closed" && !pull_request.merged) {
    // PR was closed without merging
    await updatePipelineStatus(
      repoId,
      pull_request.number,
      "status_merge",
      "closed",
      {
        closed_by: payload.sender?.login,
      },
      markChanged
    );
  }
}

// Process workflow run events (CI/CD builds)
async function processWorkflowRunEvent(payload, repoId, markChanged = null) {
  const { action, workflow_run } = payload;

  // Find associated PR
  const prNumbers = workflow_run.pull_requests?.map((pr) => pr.number) || [];

  for (const prNumber of prNumbers) {
    // Normalize build status to match Flutter PRStatus values
    if (action === "requested" || action === "in_progress") {
      await updatePipelineStatus(
        repoId,
        prNumber,
        "status_build",
        "building",
        {
          source: "workflow_run",
          status: workflow_run.status,
          run_url: workflow_run.html_url,
          workflow_name: workflow_run.name,
        },
        markChanged
      );
    } else if (action === "completed") {
      const status =
        workflow_run.conclusion === "success" ? "buildPassed" : "buildFailed";
      await updatePipelineStatus(
        repoId,
        prNumber,
        "status_build",
        status,
        {
          source: "workflow_run",
          conclusion: workflow_run.conclusion,
          run_url: workflow_run.html_url,
          workflow_name: workflow_run.name,
        },
        markChanged
      );
    }
  }
}

// Process pull request review events
async function processPullRequestReviewEvent(
  payload,
  repoId,
  markChanged = null
) {
  const { action, review, pull_request } = payload;

  if (action === "submitted") {
    if (review.state === "approved") {
      await updatePipelineStatus(
        repoId,
        pull_request.number,
        "status_approval",
        "approved",
        {
          reviewer: review.user.login,
          review_id: review.id,
          review_url: review.html_url,
        },
        markChanged
      );
    } else if (review.state === "changes_requested") {
      await updatePipelineStatus(
        repoId,
        pull_request.number,
        "status_approval",
        "changes_requested",
        {
          reviewer: review.user.login,
          review_id: review.id,
          review_url: review.html_url,
        },
        markChanged
      );
    }
  }
}

// Database helper functions
async function upsertPullRequest(prData, repoId) {
  const query = `
    INSERT INTO pull_requests (
      repo_id, pr_number, title, description, author, author_avatar, commit_sha,
      branch_name, base_branch, html_url, commit_urls, files_changed, additions, deletions,
      changed_files, commits_count, labels, assignees, reviewers, is_draft, state,
      merged, merged_at, closed_at, created_at, updated_at
    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24, NOW(), NOW())
    ON CONFLICT (repo_id, pr_number)
    DO UPDATE SET
      title = EXCLUDED.title,
      description = EXCLUDED.description,
      commit_sha = EXCLUDED.commit_sha,
      branch_name = EXCLUDED.branch_name,
      base_branch = EXCLUDED.base_branch,
      html_url = EXCLUDED.html_url,
      commit_urls = EXCLUDED.commit_urls,
      files_changed = EXCLUDED.files_changed,
      additions = EXCLUDED.additions,
      deletions = EXCLUDED.deletions,
      changed_files = EXCLUDED.changed_files,
      commits_count = EXCLUDED.commits_count,
      labels = EXCLUDED.labels,
      assignees = EXCLUDED.assignees,
      reviewers = EXCLUDED.reviewers,
      is_draft = EXCLUDED.is_draft,
      state = EXCLUDED.state,
      merged = EXCLUDED.merged,
      merged_at = EXCLUDED.merged_at,
      closed_at = EXCLUDED.closed_at,
      updated_at = NOW()
  `;

  try {
    await pool.query(query, [
      repoId,
      prData.pr_number,
      prData.title,
      prData.description,
      prData.author,
      prData.author_avatar,
      prData.commit_sha,
      prData.branch_name,
      prData.base_branch,
      prData.pr_url,
      JSON.stringify(prData.commit_urls),
      JSON.stringify(prData.files_changed),
      prData.additions,
      prData.deletions,
      prData.changed_files,
      prData.commits_count,
      JSON.stringify(prData.labels),
      JSON.stringify(prData.assignees),
      JSON.stringify(prData.reviewers),
      prData.is_draft,
      prData.state || "open",
      prData.merged || false,
      prData.merged_at,
      prData.closed_at,
    ]);

    // Append history
    const historyEntry = JSON.stringify({
      at: new Date().toISOString(),
      title: prData.title,
      state: prData.state || "open",
      commit_sha: prData.commit_sha,
    });

    await pool.query(
      `UPDATE pull_requests SET history = COALESCE(history, '[]'::jsonb) || jsonb_build_array($1::jsonb) WHERE repo_id = $2 AND pr_number = $3`,
      [historyEntry, repoId, prData.pr_number]
    );
  } catch (error) {
    console.error(
      `❌ Failed to upsert PR #${prData.pr_number}:`,
      error.message
    );
    throw error;
  }
}

async function upsertPipelineRun(repoId, prNumber, data) {
  const query = `
    INSERT INTO pipeline_runs (
      repo_id, pr_number, commit_sha, author, avatar_url, title, updated_at
    ) VALUES ($1, $2, $3, $4, $5, $6, NOW())
    ON CONFLICT (repo_id, pr_number)
    DO UPDATE SET
      commit_sha = EXCLUDED.commit_sha,
      author = EXCLUDED.author,
      avatar_url = EXCLUDED.avatar_url,
      title = EXCLUDED.title,
      updated_at = NOW()
  `;

  try {
    await pool.query(query, [
      repoId,
      prNumber,
      data.commit_sha,
      data.author || null,
      data.avatar_url || null,
      data.title || null,
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
  repoId,
  prNumber,
  statusField,
  statusValue,
  meta = null,
  markChanged = null
) {
  try {
    // First, check the current status to avoid duplicate updates
    const currentStatusQuery = `SELECT ${statusField} FROM pipeline_runs WHERE repo_id = $1 AND pr_number = $2`;
    const currentResult = await pool.query(currentStatusQuery, [
      repoId,
      prNumber,
    ]);

    let currentStatus = null;
    if (currentResult.rows.length > 0) {
      currentStatus = currentResult.rows[0][statusField];
    }

    // If status hasn't changed, don't update
    if (currentStatus === statusValue) {
      return; // No change needed, skip everything
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
      WHERE repo_id = $3 AND pr_number = $4
    `;

    await pool.query(updateQuery, [
      statusValue,
      historyEntry,
      repoId,
      prNumber,
    ]);

    // Also update PR history with state change for Flutter app consumption
    await updatePRStateHistory(repoId, prNumber, statusValue, meta);

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

// Update PR history with state changes for Flutter app
async function updatePRStateHistory(repoId, prNumber, state, meta = null) {
  try {
    const timestamp = new Date().toISOString();

    // Create state history entry
    const stateHistoryEntry = {
      state: state,
      at: timestamp,
    };

    if (meta && typeof meta === "object") {
      stateHistoryEntry.meta = meta;
    }

    // Append to PR history
    await pool.query(
      `
      UPDATE pull_requests 
      SET history = COALESCE(history, '[]'::jsonb) || jsonb_build_array($1::jsonb),
          updated_at = NOW()
      WHERE repo_id = $2 AND pr_number = $3
    `,
      [JSON.stringify(stateHistoryEntry), repoId, prNumber]
    );

    console.log(`📝 PR #${prNumber} state updated: ${state}`);
  } catch (error) {
    console.error(
      `❌ Failed to update PR #${prNumber} state history:`,
      error.message
    );
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
