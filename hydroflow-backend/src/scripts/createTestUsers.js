require('dotenv').config();
const bcrypt = require('bcryptjs');
const { pool, connectPostgres } = require('../config/db');

const TEST_USERS = [
  {
    name: 'Test Customer',
    phone: '0700000002',
    email: 'customer@HydroFlow.com',
    password: 'Customer@1234',
    role: 'resident',
  },
  {
    name: 'Test Driver',
    phone: '0700000003',
    email: 'driver@HydroFlow.com',
    password: 'Driver@1234',
    role: 'driver',
    vehicle_plate: 'KDA 123A',
    current_lat: -1.2921,
    current_lng: 36.8219,
  },
];

async function createTestUsers() {
  await connectPostgres();

  for (const u of TEST_USERS) {
    const existing = await pool.query(
      'SELECT id FROM users WHERE phone = $1 OR email = $2',
      [u.phone, u.email]
    );

    if (existing.rows.length > 0) {
      console.log(`⚠️  ${u.role} (${u.phone}) already exists — skipping.`);
      continue;
    }

    const password_hash = await bcrypt.hash(u.password, 10);

    const result = await pool.query(
      `INSERT INTO users (name, phone, email, password_hash, role, is_verified)
       VALUES ($1, $2, $3, $4, $5, TRUE)
       RETURNING id, name, phone, email, role`,
      [u.name, u.phone, u.email, password_hash, u.role]
    );

    const user = result.rows[0];

    if (u.role === 'driver') {
      await pool.query(
        `INSERT INTO drivers (user_id, vehicle_plate, is_verified, is_available, current_lat, current_lng)
         VALUES ($1, $2, TRUE, TRUE, $3, $4)`,
        [user.id, u.vehicle_plate, u.current_lat, u.current_lng]
      );
    }

    console.log(`✅ ${u.role} created: ${user.name}`);
  }

  console.log('');
  console.log('Test credentials:');
  console.log('─────────────────────────────────────');
  console.log('CUSTOMER (resident)');
  console.log('  Phone    : 0700000002');
  console.log('  Password : Customer@1234');
  console.log('─────────────────────────────────────');
  console.log('DRIVER');
  console.log('  Phone    : 0700000003');
  console.log('  Password : Driver@1234');
  console.log('  Plate    : KDA 123A');
  console.log('─────────────────────────────────────');

  await pool.end();
  process.exit(0);
}

createTestUsers().catch((err) => {
  console.error('❌ Failed:', err.message);
  process.exit(1);
});
