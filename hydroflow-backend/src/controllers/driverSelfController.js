const { pool } = require('../config/db');
const { getIo } = require('../config/socket');
const { uploadBuffer } = require('../config/cloudinary');

const emitStatus = (driverId, status) => {
  const io = getIo();
  if (io) io.to('admin-room').emit('driver:status', { driverId, status });
};

// ── helper: get driver row from user_id (upsert if missing) ──────────────────
const getOrCreateDriver = async (client, userId) => {
  await client.query(
    `INSERT INTO drivers (user_id, vehicle_plate, status, is_available, is_verified)
     VALUES ($1, 'TBD', 'offline', false, false)
     ON CONFLICT (user_id) DO NOTHING`,
    [userId]
  );
  const r = await client.query('SELECT * FROM drivers WHERE user_id = $1', [userId]);
  return r.rows[0] || null;
};

// GET /api/driver/deliveries
const getDeliveries = async (req, res) => {
  const client = await pool.connect();
  try {
    const driver = await getOrCreateDriver(client, req.user.id);
    if (!driver) return res.status(404).json({ error: 'DRIVER_NOT_FOUND', message: 'Driver profile not found' });

    const result = await client.query(
      `SELECT o.*,
              p.name           AS product_name,
              cu.name          AS customer_name,
              cu.phone         AS customer_phone
       FROM orders o
       LEFT JOIN products p  ON o.product_id = p.id
       INNER JOIN users cu   ON o.user_id = cu.id
       WHERE o.driver_id = $1
       ORDER BY o.created_at DESC`,
      [driver.id]
    );
    return res.status(200).json({ count: result.rows.length, deliveries: result.rows });
  } catch (err) {
    console.error('getDeliveries error:', err.message);
    return res.status(500).json({ error: 'SERVER_ERROR', message: 'Something went wrong.' });
  } finally {
    client.release();
  }
};

// GET /api/driver/deliveries/:id
const getDeliveryById = async (req, res) => {
  const client = await pool.connect();
  try {
    const driver = await getOrCreateDriver(client, req.user.id);
    if (!driver) return res.status(404).json({ error: 'DRIVER_NOT_FOUND', message: 'Driver profile not found' });

    const result = await client.query(
      `SELECT o.*,
              p.name        AS product_name,
              cu.name       AS customer_name,
              cu.phone      AS customer_phone,
              pod.photo_url, pod.signature_url, pod.empty_collected AS pod_empty_collected
       FROM orders o
       LEFT JOIN products p      ON o.product_id = p.id
       INNER JOIN users cu       ON o.user_id = cu.id
       LEFT JOIN proof_of_delivery pod ON pod.order_id = o.id
       WHERE o.id = $1 AND o.driver_id = $2`,
      [req.params.id, driver.id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'NOT_FOUND', message: 'Delivery not found or not assigned to you' });
    }
    return res.status(200).json({ delivery: result.rows[0] });
  } catch (err) {
    console.error('getDeliveryById error:', err.message);
    return res.status(500).json({ error: 'SERVER_ERROR', message: 'Something went wrong.' });
  } finally {
    client.release();
  }
};

// PATCH /api/driver/deliveries/:id/status
const updateDeliveryStatus = async (req, res) => {
  const client = await pool.connect();
  try {
    const { status } = req.body;
    const validStatuses = ['picked_up', 'on_the_way', 'arrived', 'delivered', 'failed'];
    if (!validStatuses.includes(status)) {
      return res.status(400).json({
        error: 'INVALID_STATUS',
        message: `Status must be one of: ${validStatuses.join(', ')}`,
      });
    }

    const driver = await getOrCreateDriver(client, req.user.id);
    if (!driver) return res.status(404).json({ error: 'DRIVER_NOT_FOUND', message: 'Driver profile not found' });

    // Map driver status to order status
    const statusMap = {
      picked_up: 'IN_TRANSIT',
      on_the_way: 'IN_TRANSIT',
      arrived: 'IN_TRANSIT',
      delivered: 'DELIVERED',
      failed: 'CANCELLED',
    };
    const orderStatus = statusMap[status];
    const isTerminal = ['DELIVERED', 'CANCELLED'].includes(orderStatus);

    await client.query('BEGIN');

    const result = await client.query(
      `UPDATE orders
       SET status = $1, completed_at = CASE WHEN $2 THEN NOW() ELSE completed_at END
       WHERE id = $3 AND driver_id = $4
       RETURNING *`,
      [orderStatus, isTerminal, req.params.id, driver.id]
    );

    if (result.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'NOT_FOUND', message: 'Delivery not found or not assigned to you' });
    }

    // Log the status change
    await client.query(
      `INSERT INTO order_status_log (order_id, status, changed_by) VALUES ($1, $2, $3)`,
      [req.params.id, orderStatus, req.user.id]
    );

    // Free driver if delivery is terminal
    if (isTerminal) {
      const active = await client.query(
        `SELECT id FROM orders WHERE driver_id = $1 AND status IN ('ASSIGNED','IN_TRANSIT') AND id != $2`,
        [driver.id, req.params.id]
      );
      if (active.rows.length === 0) {
        await client.query(
          `UPDATE drivers SET status = 'available', is_available = true WHERE id = $1`,
          [driver.id]
        );
        emitStatus(driver.id, 'available');
      }
    }

    await client.query('COMMIT');
    return res.status(200).json({ message: `Delivery marked as ${status}`, delivery: result.rows[0] });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('updateDeliveryStatus error:', err.message);
    return res.status(500).json({ error: 'SERVER_ERROR', message: 'Something went wrong.' });
  } finally {
    client.release();
  }
};

// POST /api/driver/deliveries/:id/proof
// Accepts multipart/form-data: optional `photo` and `signature` files, plus empty_collected/notes fields.
// Files are uploaded to Cloudinary; a photo_url/signature_url string in the body is still honored as a fallback.
const submitProof = async (req, res) => {
  const client = await pool.connect();
  try {
    const { empty_collected, notes } = req.body;
    let { photo_url, signature_url } = req.body;

    const driver = await getOrCreateDriver(client, req.user.id);
    if (!driver) return res.status(404).json({ error: 'DRIVER_NOT_FOUND', message: 'Driver profile not found' });

    // Verify the order belongs to this driver
    const orderCheck = await client.query(
      `SELECT id FROM orders WHERE id = $1 AND driver_id = $2`,
      [req.params.id, driver.id]
    );
    if (orderCheck.rows.length === 0) {
      return res.status(404).json({ error: 'NOT_FOUND', message: 'Delivery not found or not assigned to you' });
    }

    // Upload any captured files to Cloudinary before opening the transaction (keeps the
    // slow network call outside the DB transaction window).
    const photoFile = req.files?.photo?.[0];
    const signatureFile = req.files?.signature?.[0];
    try {
      if (photoFile) {
        photo_url = await uploadBuffer(photoFile.buffer, 'hydroflow/proof_of_delivery/photos');
      }
      if (signatureFile) {
        signature_url = await uploadBuffer(signatureFile.buffer, 'hydroflow/proof_of_delivery/signatures');
      }
    } catch (uploadErr) {
      console.error('Cloudinary upload error:', uploadErr.message);
      return res.status(502).json({ error: 'UPLOAD_FAILED', message: 'Could not upload proof image. Please try again.' });
    }

    await client.query('BEGIN');

    // Upsert proof
    const result = await client.query(
      `INSERT INTO proof_of_delivery (order_id, photo_url, signature_url, empty_collected, notes)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (order_id) DO UPDATE
         SET photo_url = EXCLUDED.photo_url,
             signature_url = EXCLUDED.signature_url,
             empty_collected = EXCLUDED.empty_collected,
             notes = EXCLUDED.notes
       RETURNING *`,
      [req.params.id, photo_url || null, signature_url || null, empty_collected ?? 0, notes || null]
    );

    // Mark order as DELIVERED
    await client.query(
      `UPDATE orders SET status = 'DELIVERED', completed_at = NOW() WHERE id = $1`,
      [req.params.id]
    );

    await client.query(
      `INSERT INTO order_status_log (order_id, status, changed_by) VALUES ($1, 'DELIVERED', $2)`,
      [req.params.id, req.user.id]
    );

    // Free driver if no other active orders
    const active = await client.query(
      `SELECT id FROM orders WHERE driver_id = $1 AND status IN ('ASSIGNED','IN_TRANSIT') AND id != $2`,
      [driver.id, req.params.id]
    );
    if (active.rows.length === 0) {
      await client.query(
        `UPDATE drivers SET status = 'available', is_available = true WHERE id = $1`,
        [driver.id]
      );
      emitStatus(driver.id, 'available');
    }

    await client.query('COMMIT');
    return res.status(201).json({ message: 'Proof submitted and delivery marked as delivered', proof: result.rows[0] });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('submitProof error:', err.message);
    return res.status(500).json({ error: 'SERVER_ERROR', message: 'Something went wrong.' });
  } finally {
    client.release();
  }
};

// PATCH /api/driver/location
const updateDriverLocation = async (req, res) => {
  try {
    const { lat, lng } = req.body;
    if (lat === undefined || lng === undefined) {
      return res.status(400).json({ error: 'MISSING_FIELDS', message: 'lat and lng are required' });
    }

    const now = new Date();
    const result = await pool.query(
      `UPDATE drivers
       SET current_lat = $1, current_lng = $2, location_updated_at = $3
       WHERE user_id = $4
       RETURNING id, current_lat, current_lng, status`,
      [lat, lng, now, req.user.id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'DRIVER_NOT_FOUND', message: 'Driver profile not found' });
    }

    const d = result.rows[0];
    const io = getIo();
    if (io) io.to('admin-room').emit('driver:location', { driverId: d.id, lat, lng, status: d.status, updatedAt: now.toISOString() });

    return res.status(200).json({ message: 'Location updated' });
  } catch (err) {
    console.error('updateDriverLocation error:', err.message);
    return res.status(500).json({ error: 'SERVER_ERROR', message: 'Something went wrong.' });
  }
};

// PATCH /api/driver/status
const updateDriverStatus = async (req, res) => {
  const client = await pool.connect();
  try {
    const { is_online } = req.body;
    if (is_online === undefined) {
      return res.status(400).json({ error: 'MISSING_FIELDS', message: 'is_online is required' });
    }

    const status = is_online ? 'available' : 'offline';
    const driver = await getOrCreateDriver(client, req.user.id);
    if (!driver) return res.status(404).json({ error: 'DRIVER_NOT_FOUND', message: 'Driver profile not found' });

    // Block going offline during active delivery
    if (!is_online) {
      const active = await client.query(
        `SELECT o.id FROM orders o
         WHERE o.driver_id = $1 AND o.status IN ('ASSIGNED','IN_TRANSIT')`,
        [driver.id]
      );
      if (active.rows.length > 0) {
        return res.status(409).json({
          error: 'ACTIVE_DELIVERY',
          message: 'Complete your active delivery before going offline.',
        });
      }
    }

    await client.query(
      `UPDATE drivers SET status = $1, is_available = $2 WHERE id = $3`,
      [status, is_online, driver.id]
    );
    emitStatus(driver.id, status);

    return res.status(200).json({ message: `You are now ${is_online ? 'online' : 'offline'}`, is_online });
  } catch (err) {
    console.error('updateDriverStatus error:', err.message);
    return res.status(500).json({ error: 'SERVER_ERROR', message: 'Something went wrong.' });
  } finally {
    client.release();
  }
};

// GET /api/driver/earnings
const getEarnings = async (req, res) => {
  const client = await pool.connect();
  try {
    const driver = await getOrCreateDriver(client, req.user.id);
    if (!driver) return res.status(404).json({ error: 'DRIVER_NOT_FOUND', message: 'Driver profile not found' });

    const earningsResult = await client.query(
      `SELECT
         COALESCE(SUM(delivery_fee) FILTER (
           WHERE DATE(completed_at) = CURRENT_DATE
             AND status IN ('DELIVERED','COMPLETED')
         ), 0)::FLOAT AS today,
         COALESCE(SUM(delivery_fee) FILTER (
           WHERE completed_at >= DATE_TRUNC('week', NOW())
             AND status IN ('DELIVERED','COMPLETED')
         ), 0)::FLOAT AS this_week,
         COALESCE(SUM(delivery_fee) FILTER (
           WHERE completed_at >= DATE_TRUNC('month', NOW())
             AND status IN ('DELIVERED','COMPLETED')
         ), 0)::FLOAT AS this_month,
         COALESCE(SUM(delivery_fee) FILTER (
           WHERE status IN ('DELIVERED','COMPLETED')
         ), 0)::FLOAT AS all_time,
         COUNT(*) FILTER (
           WHERE status IN ('DELIVERED','COMPLETED')
         )::INT AS total_deliveries,
         COUNT(*) FILTER (
           WHERE DATE(completed_at) = CURRENT_DATE
             AND status IN ('DELIVERED','COMPLETED')
         )::INT AS today_deliveries
       FROM orders
       WHERE driver_id = $1`,
      [driver.id]
    );

    // Last 14 completed deliveries for the breakdown list
    const breakdownResult = await client.query(
      `SELECT o.id, o.delivery_fee, o.completed_at, o.created_at, o.volume_liters,
              o.quantity, o.delivery_address, cu.name AS customer_name
       FROM orders o
       INNER JOIN users cu ON o.user_id = cu.id
       WHERE o.driver_id = $1 AND o.status IN ('DELIVERED','COMPLETED')
       ORDER BY o.completed_at DESC
       LIMIT 14`,
      [driver.id]
    );

    // Daily breakdown for the last 7 days (chart data)
    const dailyResult = await client.query(
      `SELECT
         DATE(completed_at)::TEXT AS day,
         SUM(delivery_fee)::FLOAT AS earnings,
         COUNT(*)::INT            AS count
       FROM orders
       WHERE driver_id = $1
         AND status IN ('DELIVERED','COMPLETED')
         AND completed_at >= NOW() - INTERVAL '7 days'
       GROUP BY DATE(completed_at)
       ORDER BY day ASC`,
      [driver.id]
    );

    return res.status(200).json({
      summary: earningsResult.rows[0],
      daily: dailyResult.rows,
      deliveries: breakdownResult.rows,
    });
  } catch (err) {
    console.error('getEarnings error:', err.message);
    return res.status(500).json({ error: 'SERVER_ERROR', message: 'Something went wrong.' });
  } finally {
    client.release();
  }
};

module.exports = {
  getDeliveries,
  getDeliveryById,
  updateDeliveryStatus,
  submitProof,
  updateDriverLocation,
  updateDriverStatus,
  getEarnings,
};
