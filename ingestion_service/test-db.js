// Test database connection
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
    const tables = await pool.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
      ORDER BY table_name
    `);
    
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
