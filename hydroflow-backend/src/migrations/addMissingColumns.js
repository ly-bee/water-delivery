require('dotenv').config();
const { pool } = require('../config/db');

const migrate = async () => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // otp_codes: store intended role so verifyOtp knows which role to assign
    await client.query(`
      ALTER TABLE otp_codes
      ADD COLUMN IF NOT EXISTS role VARCHAR(20) NOT NULL DEFAULT 'resident'
    `);
    console.log('✅ otp_codes.role added');

    // orders: quantity of jerricans
    await client.query(`
      ALTER TABLE orders
      ADD COLUMN IF NOT EXISTS quantity INTEGER NOT NULL DEFAULT 1
    `);
    console.log('✅ orders.quantity added');

    // orders: whether driver should collect empties
    await client.query(`
      ALTER TABLE orders
      ADD COLUMN IF NOT EXISTS return_empties BOOLEAN NOT NULL DEFAULT false
    `);
    console.log('✅ orders.return_empties added');

    await client.query('COMMIT');
    console.log('🎉 Migration complete');
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
