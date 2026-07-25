require('dotenv').config();

const { pool } = require('../config/db');

const createTables = async () => {
  try {
    // Table 1: users
    await pool.query(`
      CREATE TABLE IF NOT EXISTS users (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        name VARCHAR(100) NOT NULL,
        phone VARCHAR(15) UNIQUE NOT NULL,
        email VARCHAR(100) UNIQUE,
        password_hash VARCHAR(255) NOT NULL,
        role VARCHAR(20) DEFAULT 'resident',
        is_verified BOOLEAN DEFAULT FALSE,
        verification_token VARCHAR(255),
        verification_expires TIMESTAMP,
        created_at TIMESTAMP DEFAULT NOW()
      );
    `);
    console.log('✅ Users table ready');

    // Table 2: drivers
    await pool.query(`
      CREATE TABLE IF NOT EXISTS drivers (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        vehicle_plate VARCHAR(20) NOT NULL,
        is_verified BOOLEAN DEFAULT false,
        is_available BOOLEAN DEFAULT false,
        current_lat DECIMAL(10,7),
        current_lng DECIMAL(10,7)
      );
    `);
    console.log('✅ Drivers table ready');

    // Table 3: products (water packages available for order)
    await pool.query(`
      CREATE TABLE IF NOT EXISTS products (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        name VARCHAR(100) NOT NULL,
        volume_liters INTEGER NOT NULL,
        price_ksh DECIMAL(10,2) NOT NULL,
        description TEXT,
        is_active BOOLEAN DEFAULT true,
        created_at TIMESTAMP DEFAULT NOW()
      );
    `);
    console.log('✅ Products table ready');

    // Table 4: orders
    await pool.query(`
      CREATE TABLE IF NOT EXISTS orders (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID NOT NULL REFERENCES users(id),
        driver_id UUID REFERENCES drivers(id),
        product_id UUID REFERENCES products(id),
        volume_liters INTEGER NOT NULL,
        amount_ksh DECIMAL(10,2) NOT NULL,
        delivery_fee DECIMAL(10,2) NOT NULL DEFAULT 60,
        delivery_address TEXT NOT NULL,
        delivery_lat DECIMAL(10,7),
        delivery_lng DECIMAL(10,7),
        status VARCHAR(30) DEFAULT 'PENDING',
        rating INTEGER CHECK (rating >= 1 AND rating <= 5),
        notes TEXT,
        created_at TIMESTAMP DEFAULT NOW(),
        completed_at TIMESTAMP
      );
    `);
    // Idempotent — adds column to existing databases without delivery_fee
    await pool.query(`
      ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_fee DECIMAL(10,2) NOT NULL DEFAULT 60;
    `);
    console.log('✅ Orders table ready');

    // Seed default products if table is empty
    const existing = await pool.query('SELECT COUNT(*) FROM products');
    if (parseInt(existing.rows[0].count) === 0) {
      await pool.query(`
        INSERT INTO products (name, volume_liters, price_ksh, description) VALUES
        ('Small Jerrycan', 20, 50, '20-litre jerrycan — ideal for household top-up'),
        ('Standard Jerrycan', 50, 120, '50-litre jerrycan — most popular'),
        ('Half Tank', 500, 1000, '500-litre delivery — suits small households'),
        ('Full Tank', 1000, 1800, '1000-litre delivery — standard family tank'),
        ('Large Tank', 2000, 3200, '2000-litre delivery — commercial or large household');
      `);
      console.log('✅ Default products seeded');
    }

    console.log('🎉 All tables ready');

  } catch (error) {
    console.error('❌ Migration failed:', error.message);
  } finally {
    await pool.end();
  }
};

createTables();
