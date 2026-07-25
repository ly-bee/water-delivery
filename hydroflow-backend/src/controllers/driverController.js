require('dotenv').config();
const { pool }    = require('../config/db');
const { getIo }   = require('../config/socket');

/* ─── helpers ────────────────────────────────────────────────────────────── */
const emitLocation = (driverId, lat, lng, status, updatedAt) => {
  const io = getIo();
  if (io) io.to('admin-room').emit('driver:location', { driverId, lat, lng, status, updatedAt });
};

const emitStatus = (driverId, status) => {
  const io = getIo();
  if (io) io.to('admin-room').emit('driver:status', { driverId, status });
};

const haversineDistance = (lat1, lng1, lat2, lng2) => {
  const R    = 6371;
  const dLat = (lat2 - lat1) * (Math.PI / 180);
  const dLng = (lng2 - lng1) * (Math.PI / 180);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * (Math.PI / 180)) *
    Math.cos(lat2 * (Math.PI / 180)) *
    Math.sin(dLng / 2) * Math.sin(dLng / 2);
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
};

/* ─── driver self-service ────────────────────────────────────────────────── */

// POST /api/drivers/register
const registerDriver = async (req, res) => {
  try {
    const { vehicle_plate } = req.body;
    const user_id = req.user.id;

    if (!vehicle_plate) {
      return res.status(400).json({ error: 'MISSING_FIELDS', message: 'Vehicle plate is required' });
    }

    const existing = await pool.query('SELECT id FROM drivers WHERE user_id = $1', [user_id]);
    if (existing.rows.length > 0) {
      return res.status(409).json({ error: 'DRIVER_EXISTS', message: 'Driver profile already exists' });
    }

    const result = await pool.query(
      `INSERT INTO drivers (user_id, vehicle_plate) VALUES ($1, $2) RETURNING *`,
      [user_id, vehicle_plate]
    );
    return res.status(201).json({ message: 'Driver profile created', driver: result.rows[0] });
  } catch (err) {
    console.error('Register driver error:', err.message);
    return res.status(500).json({ error: 'SERVER_ERROR', message: 'Something went wrong.' });
  }
};

// PUT /api/drivers/location — driver reports their own position
const updateLocation = async (req, res) => {
  try {
    const { lat, lng } = req.body;
    const user_id = req.user.id;

    if (lat === undefined || lng === undefined) {
      return res.status(400).json({ error: 'MISSING_FIELDS', message: 'lat and lng are required' });
    }

    // Reject if driver is offline or suspended
    const check = await pool.query('SELECT status FROM drivers WHERE user_id = $1', [user_id]);
    if (check.rows.length > 0 && ['offline', 'suspended'].includes(check.rows[0].status)) {
      return res.status(403).json({ error: 'INACTIVE', message: 'Location updates are disabled while offline or suspended.' });
    }

    const now = new Date();
    const result = await pool.query(
      `UPDATE drivers
       SET current_lat = $1, current_lng = $2, location_updated_at = $3
       WHERE user_id = $4
       RETURNING *`,
      [lat, lng, now, user_id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'DRIVER_NOT_FOUND', message: 'Driver profile not found.' });
    }

    const d = result.rows[0];
    emitLocation(d.id, lat, lng, d.status, now.toISOString());

    return res.status(200).json({ message: 'Location updated', driver: d });
  } catch (err) {
    console.error('Update location error:', err.message);
    return res.status(500).json({ error: 'SERVER_ERROR', message: 'Something went wrong.' });
  }
};

// PUT /api/drivers/availability — legacy; kept for backward compat with existing Flutter app
const toggleAvailability = async (req, res) => {
  try {
    const { is_available } = req.body;
    const user_id = req.user.id;

    if (is_available === undefined) {
      return res.status(400).json({ error: 'MISSING_FIELDS', message: 'is_available is required' });
    }

    const newStatus = is_available ? 'available' : 'offline';
    const result = await pool.query(
      `UPDATE drivers
       SET is_available = $1, status = $2
       WHERE user_id = $3
       RETURNING *`,
      [is_available, newStatus, user_id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'DRIVER_NOT_FOUND', message: 'Driver profile not found' });
    }

    emitStatus(result.rows[0].id, newStatus);
    return res.status(200).json({ message: `You are now ${is_available ? 'online' : 'offline'}`, driver: result.rows[0] });
  } catch (err) {
    console.error('Toggle availability error:', err.message);
    return res.status(500).json({ error: 'SERVER_ERROR', message: 'Something went wrong.' });
  }
};

// PATCH /api/drivers/status — driver sets own status (available | offline only)
const updateDriverStatusSelf = async (req, res) => {
  try {
    const { status } = req.body;
    const user_id = req.user.id;

    if (!['available', 'offline'].includes(status)) {
      return res.status(400).json({ error: 'INVALID_STATUS', message: "Status must be 'available' or 'offline'" });
    }

    // Ensure driver profile exists (handles existing users created before auto-create fix)
    await pool.query(
      `INSERT INTO drivers (user_id, vehicle_plate, status, is_available, is_verified)
       VALUES ($1, 'TBD', 'offline', false, false)
       ON CONFLICT (user_id) DO NOTHING`,
      [user_id]
    );

    // Cannot go offline while on a delivery
    if (status === 'offline') {
      const active = await pool.query(
        `SELECT o.id FROM orders o
         JOIN drivers d ON o.driver_id = d.id
         WHERE d.user_id = $1 AND o.status IN ('ASSIGNED','IN_TRANSIT')`,
        [user_id]
      );
      if (active.rows.length > 0) {
        return res.status(409).json({
          error: 'ACTIVE_DELIVERY',
          message: 'Complete or hand off your active delivery before going offline.',
        });
      }
    }

    const result = await pool.query(
      `UPDATE drivers
       SET status = $1, is_available = $2
       WHERE user_id = $3
       RETURNING *`,
      [status, status === 'available', user_id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'DRIVER_NOT_FOUND', message: 'Driver profile not found' });
    }

    emitStatus(result.rows[0].id, status);
    return res.status(200).json({ message: `Status set to ${status}`, driver: result.rows[0] });
  } catch (err) {
    console.error('Update driver status error:', err.message);
    return res.status(500).json({ error: 'SERVER_ERROR', message: 'Something went wrong.' });
  }
};

/* ─── nearby ─────────────────────────────────────────────────────────────── */

// GET /api/drivers/nearby
const getNearbyDrivers = async (req, res) => {
  try {
    const { lat, lng, radius_km = 10 } = req.query;
    if (!lat || !lng) {
      return res.status(400).json({ error: 'MISSING_FIELDS', message: 'lat and lng are required' });
    }

    const result = await pool.query(
      `SELECT d.id, d.user_id, d.vehicle_plate, d.is_verified, d.is_available, d.status,
              d.current_lat, d.current_lng, u.name, u.phone
       FROM drivers d INNER JOIN users u ON d.user_id = u.id
       WHERE d.status = 'available' AND d.is_verified = true
         AND d.current_lat IS NOT NULL AND d.current_lng IS NOT NULL`
    );

    const withDistance = result.rows
      .map(dr => ({
        ...dr,
        distance_km: haversineDistance(parseFloat(lat), parseFloat(lng), parseFloat(dr.current_lat), parseFloat(dr.current_lng)),
      }))
      .filter(dr => dr.distance_km <= parseFloat(radius_km))
      .sort((a, b) => a.distance_km - b.distance_km);

    return res.status(200).json({ count: withDistance.length, drivers: withDistance });
  } catch (err) {
    console.error('Get nearby drivers error:', err.message);
    return res.status(500).json({ error: 'SERVER_ERROR', message: 'Something went wrong.' });
  }
};

/* ─── admin endpoints ────────────────────────────────────────────────────── */

// GET /api/drivers/admin/all
const getAllDriversAdmin = async (req, res) => {
  try {
    const { status, search } = req.query;
    const conditions = [];
    const params = [];
    let p = 1;

    if (status && status !== 'all') {
      conditions.push(`d.status = $${p++}`);
      params.push(status);
    }
    if (search) {
      conditions.push(`(u.name ILIKE $${p} OR u.phone ILIKE $${p})`);
      params.push(`%${search}%`);
      p++;
    }

    const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';

    const result = await pool.query(
      `SELECT
         d.id, d.user_id, d.vehicle_plate, d.is_verified, d.is_available,
         d.status, d.current_lat, d.current_lng, d.location_updated_at,
         u.name, u.phone, u.email,
         COALESCE(s.today_deliveries, 0)::int  AS today_deliveries,
         COALESCE(s.total_orders,     0)::int  AS total_orders,
         ROUND(COALESCE(s.avg_rating, 0)::numeric, 1) AS avg_rating,
         ao.id               AS active_order_id,
         ao.delivery_address AS active_order_address,
         ao.status           AS active_order_status
       FROM drivers d
       INNER JOIN users u ON d.user_id = u.id
       LEFT JOIN (
         SELECT
           driver_id,
           COUNT(*) FILTER (WHERE status IN ('DELIVERED','COMPLETED') AND DATE(completed_at) = CURRENT_DATE) AS today_deliveries,
           COUNT(*) AS total_orders,
           AVG(rating) FILTER (WHERE rating IS NOT NULL) AS avg_rating
         FROM orders
         GROUP BY driver_id
       ) s ON s.driver_id = d.id
       LEFT JOIN LATERAL (
         SELECT id, delivery_address, status
         FROM orders
         WHERE driver_id = d.id AND status IN ('ASSIGNED','IN_TRANSIT')
         ORDER BY created_at DESC
         LIMIT 1
       ) ao ON true
       ${where}
       ORDER BY
         CASE d.status
           WHEN 'available'   THEN 1
           WHEN 'on_delivery' THEN 2
           WHEN 'offline'     THEN 3
           WHEN 'suspended'   THEN 4
           ELSE 5
         END, u.name ASC`,
      params
    );

    return res.status(200).json({ count: result.rows.length, drivers: result.rows });
  } catch (err) {
    console.error('Get all drivers error:', err.message);
    return res.status(500).json({ error: 'SERVER_ERROR', message: 'Something went wrong.' });
  }
};

// GET /api/drivers/admin/locations — lightweight polling fallback for the map
const getDriverLocations = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT d.id, d.status, d.current_lat, d.current_lng, d.location_updated_at
       FROM drivers d
       WHERE d.current_lat IS NOT NULL AND d.current_lng IS NOT NULL`
    );
    return res.status(200).json({ locations: result.rows });
  } catch (err) {
    console.error('Get driver locations error:', err.message);
    return res.status(500).json({ error: 'SERVER_ERROR', message: 'Something went wrong.' });
  }
};

// GET /api/drivers/admin/:id — full detail
const getDriverDetailAdmin = async (req, res) => {
  try {
    const { id } = req.params;

    const [profileRes, perfRes, histRes] = await Promise.all([
      pool.query(
        `SELECT d.*, u.name, u.phone, u.email
         FROM drivers d INNER JOIN users u ON d.user_id = u.id
         WHERE d.id = $1`,
        [id]
      ),
      pool.query(
        `SELECT
           COUNT(*) AS total_orders,
           COUNT(*) FILTER (WHERE status IN ('DELIVERED','COMPLETED')) AS completed,
           COUNT(*) FILTER (WHERE status = 'CANCELLED') AS cancelled,
           ROUND(100.0 * COUNT(*) FILTER (WHERE status IN ('DELIVERED','COMPLETED'))
                 / NULLIF(COUNT(*), 0), 1) AS completion_rate,
           ROUND(AVG(rating) FILTER (WHERE rating IS NOT NULL)::numeric, 1) AS avg_rating,
           COUNT(*) FILTER (
             WHERE status IN ('DELIVERED','COMPLETED') AND DATE(completed_at) = CURRENT_DATE
           ) AS today_deliveries
         FROM orders WHERE driver_id = $1`,
        [id]
      ),
      pool.query(
        `SELECT o.id, o.status, o.volume_liters, o.amount_ksh, o.delivery_address,
                o.created_at, o.completed_at, o.rating,
                u.name AS customer_name
         FROM orders o LEFT JOIN users u ON o.user_id = u.id
         WHERE o.driver_id = $1
         ORDER BY o.created_at DESC LIMIT 10`,
        [id]
      ),
    ]);

    if (profileRes.rows.length === 0) {
      return res.status(404).json({ error: 'DRIVER_NOT_FOUND', message: 'Driver not found' });
    }

    return res.status(200).json({
      profile:     profileRes.rows[0],
      performance: perfRes.rows[0],
      history:     histRes.rows,
    });
  } catch (err) {
    console.error('Get driver detail error:', err.message);
    return res.status(500).json({ error: 'SERVER_ERROR', message: 'Something went wrong.' });
  }
};

// PUT /api/drivers/:id/verify — verify (admin)
const verifyDriver = async (req, res) => {
  try {
    const { id } = req.params;
    const { is_verified } = req.body;

    const result = await pool.query(
      'UPDATE drivers SET is_verified = $1 WHERE id = $2 RETURNING *',
      [is_verified !== false, id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'DRIVER_NOT_FOUND', message: 'Driver not found' });
    }
    return res.status(200).json({
      message: `Driver ${result.rows[0].is_verified ? 'verified' : 'unverified'}`,
      driver: result.rows[0],
    });
  } catch (err) {
    console.error('Verify driver error:', err.message);
    return res.status(500).json({ error: 'SERVER_ERROR', message: 'Something went wrong.' });
  }
};

// PATCH /api/drivers/admin/:id/status — admin suspends or reactivates
const updateDriverStatusAdmin = async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;

    if (!['suspended', 'available', 'offline'].includes(status)) {
      return res.status(400).json({
        error: 'INVALID_STATUS',
        message: "Status must be 'suspended', 'available', or 'offline'",
      });
    }

    const result = await pool.query(
      `UPDATE drivers
       SET status = $1, is_available = $2
       WHERE id = $3
       RETURNING *`,
      [status, status === 'available', id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'DRIVER_NOT_FOUND', message: 'Driver not found' });
    }

    emitStatus(id, status);
    return res.status(200).json({ message: `Driver status set to ${status}`, driver: result.rows[0] });
  } catch (err) {
    console.error('Admin update driver status error:', err.message);
    return res.status(500).json({ error: 'SERVER_ERROR', message: 'Something went wrong.' });
  }
};

// PATCH /api/drivers/admin/:id/reassign — reassign the driver's active order to another driver
const reassignOrderAdmin = async (req, res) => {
  const client = await pool.connect();
  try {
    const { id: old_driver_id } = req.params;
    const { new_driver_id, order_id } = req.body;

    if (!new_driver_id) {
      return res.status(400).json({ error: 'MISSING_FIELDS', message: 'new_driver_id is required' });
    }

    // Resolve the order to reassign
    let targetOrderId = order_id;
    if (!targetOrderId) {
      const r = await client.query(
        `SELECT id FROM orders WHERE driver_id = $1 AND status IN ('ASSIGNED','IN_TRANSIT')
         ORDER BY created_at DESC LIMIT 1`,
        [old_driver_id]
      );
      if (r.rows.length === 0) {
        return res.status(404).json({ error: 'NO_ACTIVE_ORDER', message: 'This driver has no active order to reassign.' });
      }
      targetOrderId = r.rows[0].id;
    }

    await client.query('BEGIN');

    // Transfer the order
    await client.query(
      `UPDATE orders SET driver_id = $1 WHERE id = $2`,
      [new_driver_id, targetOrderId]
    );

    // Free old driver if they have no remaining active orders
    const remaining = await client.query(
      `SELECT id FROM orders WHERE driver_id = $1 AND status IN ('ASSIGNED','IN_TRANSIT') AND id != $2`,
      [old_driver_id, targetOrderId]
    );
    const oldStatus = remaining.rows.length === 0 ? 'available' : 'on_delivery';
    await client.query(
      `UPDATE drivers SET status = $1, is_available = $2 WHERE id = $3`,
      [oldStatus, oldStatus === 'available', old_driver_id]
    );

    // Mark new driver as on_delivery
    await client.query(
      `UPDATE drivers SET status = 'on_delivery', is_available = false WHERE id = $1`,
      [new_driver_id]
    );

    await client.query('COMMIT');

    emitStatus(old_driver_id, oldStatus);
    emitStatus(new_driver_id, 'on_delivery');

    return res.status(200).json({ message: 'Order reassigned successfully', order_id: targetOrderId });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Reassign order error:', err.message);
    return res.status(500).json({ error: 'SERVER_ERROR', message: 'Something went wrong.' });
  } finally {
    client.release();
  }
};

module.exports = {
  registerDriver,
  updateLocation,
  toggleAvailability,
  updateDriverStatusSelf,
  getNearbyDrivers,
  getAllDriversAdmin,
  getDriverLocations,
  getDriverDetailAdmin,
  verifyDriver,
  updateDriverStatusAdmin,
  reassignOrderAdmin,
};
