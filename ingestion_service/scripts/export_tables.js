const { Pool } = require("pg");
const fs = require("fs");
const path = require("path");

// Load environment variables from .env file
require("dotenv").config({ path: path.join(__dirname, "..", ".env") });

// Database configuration
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.NODE_ENV === "production" ? true : false,
});

// Tables to export with their respective timestamp columns
const TABLES_TO_EXPORT = [
  { name: "pull_requests", timestampColumn: "created_at" },
  { name: "pipeline_runs", timestampColumn: "created_at" },
  { name: "insights", timestampColumn: "created_at" },
  { name: "raw_events", timestampColumn: "received_at" },
];

async function exportTables() {
  try {
    console.log("🔍 Connecting to database...");
    await pool.query("SELECT NOW()");
    console.log("✅ Connected");

    // Clear exports folder
    const outputDir = path.join(__dirname, "..", "exports");
    if (fs.existsSync(outputDir)) {
      console.log("Clearing exports folder...");
      fs.rmSync(outputDir, { recursive: true, force: true });
    }
    fs.mkdirSync(outputDir, { recursive: true });

    // Export each table
    for (const tableConfig of TABLES_TO_EXPORT) {
      const { name: tableName, timestampColumn } = tableConfig;
      console.log(`Exporting ${tableName}...`);

      const result = await pool.query(
        `SELECT * FROM ${tableName} ORDER BY ${timestampColumn} DESC`
      );
      const data = {
        table: tableName,
        exported_at: new Date().toISOString(),
        count: result.rows.length,
        data: result.rows,
      };

      const filename = `${tableName}.json`;
      const filepath = path.join(outputDir, filename);

      fs.writeFileSync(filepath, JSON.stringify(data, null, 2));
      console.log(`✅ ${tableName}: ${result.rows.length} records`);
    }

    console.log("Export completed!");
    console.log(`Files saved in: ${outputDir}`);
  } catch (error) {
    console.error("❌ Export failed:", error.message);
  } finally {
    await pool.end();
  }
}

// Run if called directly
if (require.main === module) {
  console.log("Starting Database Export");
  exportTables();
}

module.exports = { exportTables };
