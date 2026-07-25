require('dotenv').config();
const { Pool } = require('pg');
const bcrypt = require('bcryptjs');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

async function seed() {
  const drivers = [
    { name: 'James Mwangi', phone: '0731111111', lat: -1.0850, lng: 37.0200, plate: 'KCA 001A' },
    { name: 'Peter Kamau',  phone: '0732222222', lat: -1.1100, lng: 37.0050, plate: 'KCB 002B' },
    { name: 'John Njoroge', phone: '0733333333', lat: -1.0750, lng: 36.9900, plate: 'KCC 003C' },
  ];

  const password_hash = await bcrypt.hash('password123', 10);

  for (const d of drivers) {
    const userResult = await pool.query(
      `INSERT INTO users (name, phone, password_hash, role, is_verified)
       VALUES ($1, $2, $3, 'driver', TRUE)
       ON CONFLICT (phone) DO UPDATE SET name = EXCLUDED.name
       RETURNING id`,
      [d.name, d.phone, password_hash]
    );
    const userId = userResult.rows[0].id;

    await pool.query(
      `INSERT INTO drivers (user_id, vehicle_plate, latitude, longitude, is_available, is_verified)
       VALUES ($1, $2, $3, $4, TRUE, TRUE)
       ON CONFLICT (user_id) DO UPDATE
       SET vehicle_plate = EXCLUDED.vehicle_plate,
           latitude = EXCLUDED.latitude,
           longitude = EXCLUDED.longitude,
           is_available = TRUE,
           is_verified = TRUE`,
      [userId, d.plate, d.lat, d.lng]
    );
    console.log('✅ Driver added:', d.name);
  }

  // Update existing driver too
  await pool.query(
    `UPDATE drivers SET latitude = -1.0996, longitude = 37.0144,
     is_available = TRUE, is_verified = TRUE
     WHERE latitude IS NULL`
  );

  console.log('✅ All drivers seeded successfully');
  process.exit(0);
}

seed().catch(e => {
  console.error(e.message);
  process.exit(1);
});