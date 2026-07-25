require('dotenv').config();
const bcrypt = require('bcryptjs');
const { pool, connectPostgres } = require('../config/db');

const ADMIN = {
  name: 'HydroFlow Admin',
  phone: '0700000001',
  email: 'admin@HydroFlow.com',
  password: 'Admin@1234',
  role: 'admin',
};

async function createAdmin() {
  await connectPostgres();

  const existing = await pool.query('SELECT id FROM users WHERE phone = $1 OR email = $2', [
    ADMIN.phone,
    ADMIN.email,
  ]);

  if (existing.rows.length > 0) {
    console.log('⚠️  Admin already exists — no changes made.');
    process.exit(0);
  }

  const password_hash = await bcrypt.hash(ADMIN.password, 10);

  const result = await pool.query(
    `INSERT INTO users (name, phone, email, password_hash, role, is_verified)
     VALUES ($1, $2, $3, $4, $5, TRUE)
     RETURNING id, name, phone, email, role`,
    [ADMIN.name, ADMIN.phone, ADMIN.email, password_hash, ADMIN.role]
  );

  const user = result.rows[0];
  console.log('✅ Admin created successfully!');
  console.log(`   Name  : ${user.name}`);
  console.log(`   Phone : ${user.phone}`);
  console.log(`   Email : ${user.email}`);
  console.log(`   Role  : ${user.role}`);
  console.log('');
  console.log('Login credentials:');
  console.log(`   Phone    : ${ADMIN.phone}`);
  console.log(`   Password : ${ADMIN.password}`);

  await pool.end();
  process.exit(0);
}

createAdmin().catch((err) => {
  console.error('❌ Failed to create admin:', err.message);
  process.exit(1);
});
