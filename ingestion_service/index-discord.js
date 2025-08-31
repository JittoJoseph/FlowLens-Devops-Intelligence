const express = require("express");
const bodyParser = require("body-parser");
const crypto = require("crypto");
const https = require("https");
const fs = require("fs");
const path = require("path");
const FormData = require("form-data");

const app = express();
const PORT = process.env.PORT || 3000;

// Discord webhook URL (hardcoded for testing)
const DISCORD_WEBHOOK_URL =
  "https://discord.com/api/webhooks/1411621971262705715/PXPiT3Z6LXF27ueI_1sTQN-8lMCzU4bvlkxUIn0MKnoihUijKJHwkxIvKbNcALi1AMFr";

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

// Send raw JSON data to Discord as file attachment
async function sendToDiscord(eventType, payload, deliveryId) {
  const timestamp = new Date().toISOString();
  const filename = `${timestamp.replace(
    /[:.]/g,
    "-"
  )}_${eventType}_${deliveryId}.json`;

  // Create complete JSON object with metadata
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
    await sendDiscordFile(jsonContent, filename, eventType, deliveryId);
    console.log(
      `✅ Raw ${eventType} event sent to Discord as file: ${filename}`
    );
  } catch (error) {
    console.error(
      `❌ Failed to send ${eventType} event to Discord:`,
      error.message
    );
    throw error;
  }
}

// Helper function to send file to Discord
async function sendDiscordFile(jsonContent, filename, eventType, deliveryId) {
  const form = new FormData();

  // Add the JSON file
  form.append("files[0]", Buffer.from(jsonContent, "utf8"), {
    filename: filename,
    contentType: "application/json",
  });

  // Add message content
  const messageContent = {
    content: `📦 **GitHub ${eventType} Event**\n🆔 Delivery ID: \`${deliveryId}\`\n⏰ Timestamp: \`${new Date().toISOString()}\``,
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
      res.on("data", (chunk) => {
        data += chunk;
      });
      res.on("end", () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          resolve(data);
        } else {
          console.error(
            `❌ Discord file upload failed: ${res.statusCode} - ${data}`
          );
          reject(new Error(`Discord file upload failed: ${res.statusCode}`));
        }
      });
    });

    req.on("error", (error) => {
      console.error("❌ Error sending file to Discord:", error);
      reject(error);
    });

    form.pipe(req);
  });
}

// Save event to local file (for backup/debugging)
function saveEventToFile(eventType, payload, deliveryId) {
  const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
  const filename = `${timestamp}_${eventType}_${deliveryId}.json`;
  const filepath = path.join(logsDir, filename);

  const eventData = {
    timestamp: new Date().toISOString(),
    eventType,
    deliveryId,
    payload,
  };

  fs.writeFileSync(filepath, JSON.stringify(eventData, null, 2));
  console.log(`💾 Saved event to: ${filename}`);
}

// Health check endpoint
app.get("/health", (req, res) => {
  res.json({
    status: "healthy",
    service: "FlowLens Ingestion Service (Discord File Mode)",
    timestamp: new Date().toISOString(),
    discordWebhook: "configured",
    mode: "file-upload-only",
  });
});

// Root endpoint
app.get("/", (req, res) => {
  res.json({
    service: "FlowLens Ingestion Service (Discord File Mode)",
    description: "GitHub webhook processor with Discord JSON file uploads",
    version: "1.0.0-discord-file",
    endpoints: {
      health: "/health",
      webhook: "/webhook (POST)",
      events: "/events (GET)",
    },
    mode: "JSON file uploads only",
  });
});

// Main webhook endpoint
app.post("/webhook", async (req, res) => {
  const signature = req.get("X-Hub-Signature-256");
  const eventType = req.get("X-GitHub-Event");
  const deliveryId = req.get("X-GitHub-Delivery");

  console.log(`\n📥 Received ${eventType} event (delivery: ${deliveryId})`);
  console.log(`🕐 Timestamp: ${new Date().toISOString()}`);

  // Verify signature
  if (!verifyGitHubSignature(JSON.stringify(req.body), signature)) {
    console.error("❌ Invalid webhook signature");
    return res.status(401).json({ error: "Invalid signature" });
  }

  try {
    // Save to local file for backup
    saveEventToFile(eventType, req.body, deliveryId);

    // Send to Discord as JSON file
    await sendToDiscord(eventType, req.body, deliveryId);

    console.log(`✅ Successfully processed ${eventType} event`);
    res.status(200).json({
      success: true,
      eventType,
      deliveryId,
      message: "Event processed and sent to Discord as JSON file",
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    console.error("❌ Error processing webhook:", error);
    res.status(500).json({
      error: "Internal server error",
      details:
        process.env.NODE_ENV === "development" ? error.message : undefined,
      eventType,
      deliveryId,
    });
  }
});

// Get recent events (for debugging)
app.get("/events", async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 20;
    const files = fs
      .readdirSync(logsDir)
      .filter((file) => file.endsWith(".json"))
      .sort()
      .reverse()
      .slice(0, limit);

    const events = files.map((file) => {
      const filepath = path.join(logsDir, file);
      const content = JSON.parse(fs.readFileSync(filepath, "utf8"));
      return {
        file,
        timestamp: content.timestamp,
        eventType: content.eventType,
        deliveryId: content.deliveryId,
        // Don't include full payload in list view
        payloadSize: JSON.stringify(content.payload).length,
      };
    });

    res.json({
      totalEvents: files.length,
      events,
      logsDirectory: logsDir,
    });
  } catch (error) {
    console.error("❌ Error reading events:", error);
    res.status(500).json({ error: "Failed to read events" });
  }
});

// Get specific event details
app.get("/events/:filename", (req, res) => {
  try {
    const filename = req.params.filename;
    if (!filename.endsWith(".json")) {
      return res.status(400).json({ error: "Invalid filename" });
    }

    const filepath = path.join(logsDir, filename);
    if (!fs.existsSync(filepath)) {
      return res.status(404).json({ error: "Event file not found" });
    }

    const content = JSON.parse(fs.readFileSync(filepath, "utf8"));
    res.json(content);
  } catch (error) {
    console.error("❌ Error reading event file:", error);
    res.status(500).json({ error: "Failed to read event file" });
  }
});

// Graceful shutdown
process.on("SIGTERM", async () => {
  console.log("🛑 Received SIGTERM, shutting down gracefully...");
  process.exit(0);
});

process.on("SIGINT", async () => {
  console.log("🛑 Received SIGINT, shutting down gracefully...");
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
  console.log(
    `\n🚀 FlowLens Ingestion Service (Discord File Mode) running on port ${PORT}`
  );
  console.log(`📡 Webhook endpoint: http://localhost:${PORT}/webhook`);
  console.log(`🏥 Health check: http://localhost:${PORT}/health`);
  console.log(`📋 Recent events: http://localhost:${PORT}/events`);
  console.log(`💬 Discord webhook: ${DISCORD_WEBHOOK_URL.substring(0, 50)}...`);
  console.log(`📁 Logs directory: ${logsDir}`);

  if (!WEBHOOK_SECRET) {
    console.warn("\n⚠️  WARNING: GITHUB_WEBHOOK_SECRET not set!");
    console.warn("   Webhook signature verification is disabled.");
    console.warn(
      "   Set GITHUB_WEBHOOK_SECRET environment variable for security."
    );
  }

  console.log(
    "\n✨ Ready to receive GitHub webhooks and upload JSON files to Discord!"
  );
});
