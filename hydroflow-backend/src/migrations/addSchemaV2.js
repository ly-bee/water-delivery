require('dotenv').config();
const { pool } = require('../config/db');

const migrate = async () => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // ── orders: add M-Pesa + order-type columns ──────────────────────────
    await client.query(`ALTER TABLE orders ADD COLUMN IF NOT EXISTS order_type        VARCHAR(10)  DEFAULT 'refill'`);
    await client.query(`ALTER TABLE orders ADD COLUMN IF NOT EXISTS collect_empty     BOOLEAN      DEFAULT false`);
    await client.query(`ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_method    VARCHAR(30)  DEFAULT 'mpesa'`);
    await client.query(`ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_status    VARCHAR(20)  DEFAULT 'PENDING'`);
    await client.query(`ALTER TABLE orders ADD COLUMN IF NOT EXISTS scheduled_time    TIMESTAMP`);
    await client.query(`ALTER TABLE orders ADD COLUMN IF NOT EXISTS special_instructions TEXT`);
    await client.query(`ALTER TABLE orders ADD COLUMN IF NOT EXISTS mpesa_checkout_id VARCHAR(100)`);
    await client.query(`ALTER TABLE orders ADD COLUMN IF NOT EXISTS mpesa_receipt     VARCHAR(50)`);
    await client.query(`ALTER TABLE orders ADD COLUMN IF NOT EXISTS paid_at           TIMESTAMP`);
    console.log('✅ orders columns added');

    // ── drivers: add profile + rating columns ─────────────────────────────
    await client.query(`ALTER TABLE drivers ADD COLUMN IF NOT EXISTS vehicle_info  TEXT`);
    await client.query(`ALTER TABLE drivers ADD COLUMN IF NOT EXISTS rating        DECIMAL(3,2) DEFAULT 0.0`);
    console.log('✅ drivers columns added');

    // ── order_status_log ──────────────────────────────────────────────────
    await client.query(`
      CREATE TABLE IF NOT EXISTS order_status_log (
        id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        order_id    UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
        status      VARCHAR(30) NOT NULL,
        changed_by  UUID REFERENCES users(id),
        changed_at  TIMESTAMP DEFAULT NOW()
      )
    `);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_osl_order ON order_status_log(order_id)`);
    console.log('✅ order_status_log table ready');

    // ── proof_of_delivery ─────────────────────────────────────────────────
    await client.query(`
      CREATE TABLE IF NOT EXISTS proof_of_delivery (
        id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        order_id         UUID NOT NULL UNIQUE REFERENCES orders(id) ON DELETE CASCADE,
        photo_url        TEXT,
        signature_url    TEXT,
        empty_collected  INTEGER DEFAULT 0,
        notes            TEXT,
        created_at       TIMESTAMP DEFAULT NOW()
      )
    `);
    console.log('✅ proof_of_delivery table ready');

    await client.query('COMMIT');
    console.log('🎉 Schema v2 migration complete');
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
