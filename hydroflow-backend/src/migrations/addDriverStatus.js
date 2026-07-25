require('dotenv').config();
const { pool } = require('../config/db');

const migrate = async () => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    await client.query(`
      ALTER TABLE drivers
      ADD COLUMN IF NOT EXISTS status VARCHAR(20) NOT NULL DEFAULT 'offline'
    `);

    await client.query(`
      ALTER TABLE drivers
      ADD COLUMN IF NOT EXISTS location_updated_at TIMESTAMP
    `);

    // Migrate is_available → status for existing rows
    await client.query(`
      UPDATE drivers
      SET status = 'available'
      WHERE is_available = true AND status = 'offline'
    `);

    await client.query('COMMIT');
    console.log('✅ Driver status migration complete');
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('❌ Migration failed:', err.message);
    process.exit(1);
  } finally {
    client.release();
    await pool.end();
  }
};

migrate();
