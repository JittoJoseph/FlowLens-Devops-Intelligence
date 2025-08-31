#!/usr/bin/env node

const crypto = require("crypto");
const fs = require("fs");
const path = require("path");
const { exec } = require("child_process");

console.log("🚀 FlowLens Ingestion Service Setup");
console.log("=====================================\n");

// Generate webhook secret
const webhookSecret = crypto.randomBytes(32).toString("hex");
console.log("🔐 Generated webhook secret:");
console.log(`   ${webhookSecret}\n`);

// Create .env file if it doesn't exist
const envPath = path.join(__dirname, ".env");
if (!fs.existsSync(envPath)) {
  const envContent = `# FlowLens Ingestion Service Configuration
# ========================================

# YugabyteDB Connection
# Get this from your YugabyteDB Cloud dashboard
# Format: postgresql://admin:password@host:port/yugabyte?ssl=true
DATABASE_URL=postgresql://username:password@host:port/database?ssl=true

# GitHub Webhook Secret
# Use this EXACT value when setting up GitHub webhook
GITHUB_WEBHOOK_SECRET=${webhookSecret}

# Server Configuration
PORT=3000
NODE_ENV=development

# Example YugabyteDB Cloud URL:
# DATABASE_URL=postgresql://admin:your_password@12345-demo.aws.ybdb.io:5433/yugabyte?ssl=true
`;

  fs.writeFileSync(envPath, envContent);
  console.log("✅ Created .env file with generated secret\n");
} else {
  console.log("ℹ️  .env file already exists\n");
}

// Check if dependencies are installed
if (!fs.existsSync(path.join(__dirname, "node_modules"))) {
  console.log("📦 Installing dependencies...");
  exec("npm install", (error, stdout, stderr) => {
    if (error) {
      console.error("❌ Failed to install dependencies:", error.message);
      return;
    }
    console.log("✅ Dependencies installed successfully\n");
    showNextSteps();
  });
} else {
  console.log("✅ Dependencies already installed\n");
  showNextSteps();
}

function showNextSteps() {
  console.log("📋 Setup Steps:");
  console.log("==============\n");

  console.log("1️⃣  Database Setup:");
  console.log("   • Go to https://cloud.yugabyte.com/");
  console.log("   • Create free Sandbox cluster");
  console.log("   • Run schema from YUGABYTE_SETUP.md");
  console.log("   • Update DATABASE_URL in .env file\n");

  console.log("2️⃣  Test Local Service:");
  console.log("   • Run: npm run dev");
  console.log("   • Visit: http://localhost:3000/health");
  console.log("   • Check database connection in logs\n");

  console.log("3️⃣  Deploy to Render:");
  console.log("   • Follow RENDER_DEPLOYMENT.md guide");
  console.log(
    "   • Use webhook secret:",
    webhookSecret.substring(0, 16) + "..."
  );
  console.log("   • Set environment variables in Render\n");

  console.log("4️⃣  Setup GitHub Webhook:");
  console.log("   • Follow GITHUB_WEBHOOK_SETUP.md guide");
  console.log("   • Webhook URL: https://your-app.onrender.com/webhook");
  console.log("   • Secret:", webhookSecret.substring(0, 16) + "...\n");

  console.log("5️⃣  Test End-to-End:");
  console.log("   • Create test PR in repository");
  console.log("   • Check webhook delivery in GitHub");
  console.log("   • Verify events in service logs\n");

  console.log("🔗 Documentation:");
  console.log("================");
  console.log("• README.md           - Service overview");
  console.log("• YUGABYTE_SETUP.md   - Database setup");
  console.log("• GITHUB_WEBHOOK_SETUP.md - Webhook configuration");
  console.log("• RENDER_DEPLOYMENT.md    - Deployment guide\n");

  console.log("🆘 Quick Commands:");
  console.log("================");
  console.log("• npm run dev         - Start development server");
  console.log("• npm start           - Start production server");
  console.log("• npm run docker:build - Build Docker image");
  console.log("• node test-db.js     - Test database connection\n");

  console.log("🎯 Service Endpoints (once running):");
  console.log("===================================");
  console.log("• GET  /              - Service info");
  console.log("• GET  /health        - Health check");
  console.log("• POST /webhook       - GitHub webhook receiver");
  console.log("• GET  /events        - Recent events (debug)\n");

  console.log("✨ Ready to build the future of DevOps! ✨");
}

// Create test database connection file
const testDbContent = `// Test database connection
const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
});

async function testConnection() {
  try {
    console.log('🔄 Testing database connection...');
    const result = await pool.query('SELECT NOW() as current_time, version() as version');
    console.log('✅ Database connected successfully!');
    console.log('📅 Current time:', result.rows[0].current_time);
    console.log('🗄️  Database version:', result.rows[0].version.split(' ')[0]);
    
    // Test tables exist
    const tables = await pool.query(\`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
      ORDER BY table_name
    \`);
    
    if (tables.rows.length > 0) {
      console.log('📋 Available tables:');
      tables.rows.forEach(row => console.log('   •', row.table_name));
    } else {
      console.log('⚠️  No tables found - run schema from YUGABYTE_SETUP.md');
    }
    
  } catch (error) {
    console.error('❌ Database connection failed:');
    console.error('   Message:', error.message);
    console.error('   Hint: Check DATABASE_URL in .env file');
  } finally {
    await pool.end();
  }
}

testConnection();
`;

fs.writeFileSync(path.join(__dirname, "test-db.js"), testDbContent);
console.log("✅ Created test-db.js for database testing");
