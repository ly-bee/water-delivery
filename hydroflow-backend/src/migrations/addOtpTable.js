require('dotenv').config();

const { pool } = require('../config/db');

const addOtpTable = async () => {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS otp_codes (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        phone VARCHAR(15) NOT NULL,
        code VARCHAR(6) NOT NULL,
        attempts INTEGER DEFAULT 0,
        created_at TIMESTAMP DEFAULT NOW(),
        expires_at TIMESTAMP NOT NULL
      );
    `);
    console.log('✅ OTP codes table created');

    await pool.query(`
      CREATE INDEX IF NOT EXISTS idx_otp_phone ON otp_codes(phone);
    `);
    console.log('✅ OTP index created');

    process.exit(0);
  } catch (error) {
    console.error('❌ Migration failed:', error.message);
    process.exit(1);
  }
};

addOtpTable();

