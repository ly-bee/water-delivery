const { pool } = require('../config/db');

// GET /api/users/me  — returns user + driver fields for driver role
const getMe = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT u.id, u.name, u.phone, u.email, u.role, u.is_verified, u.created_at,
              d.vehicle_info, d.vehicle_plate,
              ROUND(d.rating::NUMERIC, 2)::FLOAT AS driver_rating,
              d.status AS driver_status
       FROM users u
       LEFT JOIN drivers d ON d.user_id = u.id
       WHERE u.id = $1`,
      [req.user.id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'NOT_FOUND', message: 'User not found' });
    }
    return res.status(200).json({ user: result.rows[0] });
  } catch (error) {
    console.error('Get me error:', error.message);
    return res.status(500).json({ error: 'SERVER_ERROR', message: 'Something went wrong.' });
  }
};

// PUT /api/users/me  — update name, email, and driver vehicle details
const updateMe = async (req, res) => {
  const { name, email, vehicle_info, vehicle_plate } = req.body;
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // Build users SET clause dynamically
    const userSets  = [];
    const userParams = [];
    let idx = 1;

    if (name !== undefined && name.trim()) {
      userSets.push(`name = $${idx++}`);
      userParams.push(name.trim());
    }
    if (email !== undefined) {
      const trimmed = email?.trim() || null;
      userSets.push(`email = $${idx++}`);
      userParams.push(trimmed);
    }

    let user;
    if (userSets.length > 0) {
      userParams.push(req.user.id);
      const r = await client.query(
        `UPDATE users SET ${userSets.join(', ')}
         WHERE id = $${idx}
         RETURNING id, name, phone, email, role, is_verified, created_at`,
        userParams
      );
      user = r.rows[0];
    } else {
      const r = await client.query(
        `SELECT id, name, phone, email, role, is_verified, created_at FROM users WHERE id = $1`,
        [req.user.id]
      );
      user = r.rows[0];
    }

    // Update drivers table if applicable
    let driverExtra = null;
    if (req.user.role === 'driver') {
      const driverSets   = [];
      const driverParams = [];
      let di = 1;

      if (vehicle_info !== undefined) {
        driverSets.push(`vehicle_info = $${di++}`);
        driverParams.push(vehicle_info?.trim() || null);
      }
      if (vehicle_plate !== undefined && vehicle_plate?.trim()) {
        driverSets.push(`vehicle_plate = $${di++}`);
        driverParams.push(vehicle_plate.trim());
      }

      if (driverSets.length > 0) {
        driverParams.push(req.user.id);
        const dr = await client.query(
          `UPDATE drivers SET ${driverSets.join(', ')}
           WHERE user_id = $${di}
           RETURNING vehicle_info, vehicle_plate,
                     ROUND(rating::NUMERIC,2)::FLOAT AS driver_rating,
                     status AS driver_status`,
          driverParams
        );
        driverExtra = dr.rows[0] || null;
      } else {
        const dr = await client.query(
          `SELECT vehicle_info, vehicle_plate,
                  ROUND(rating::NUMERIC,2)::FLOAT AS driver_rating,
                  status AS driver_status
           FROM drivers WHERE user_id = $1`,
          [req.user.id]
        );
        driverExtra = dr.rows[0] || null;
      }
    }

    await client.query('COMMIT');
    return res.status(200).json({
      message: 'Profile updated',
      user: { ...user, ...driverExtra },
    });
  } catch (error) {
    await client.query('ROLLBACK');
    // Unique constraint on email
    if (error.code === '23505') {
      return res.status(409).json({ error: 'EMAIL_IN_USE', message: 'This email is already registered to another account.' });
    }
    console.error('Update me error:', error.message);
    return res.status(500).json({ error: 'SERVER_ERROR', message: 'Something went wrong.' });
  } finally {
    client.release();
  }
};

// GET /api/users — admin only
const getAllUsers = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT id, name, phone, email, role, is_verified, created_at
       FROM users ORDER BY created_at DESC`
    );
    return res.status(200).json({ count: result.rows.length, users: result.rows });
  } catch (error) {
    console.error('Get users error:', error.message);
    return res.status(500).json({ error: 'SERVER_ERROR', message: 'Something went wrong.' });
  }
};

module.exports = { getAllUsers, getMe, updateMe };
