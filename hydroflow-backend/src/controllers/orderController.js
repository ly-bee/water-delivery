require('dotenv').config();
const { pool } = require('../config/db');

// POST /api/orders — Create order
const createOrder = async (req, res) => {
  try {
    const {
      product_id, volume_liters, amount_ksh,
      delivery_fee,
      delivery_address, delivery_lat, delivery_lng,
      notes, quantity, return_empties,
    } = req.body;
    const user_id = req.user.id;

    if (!volume_liters || !amount_ksh || !delivery_address) {
      return res.status(400).json({
        error: 'MISSING_FIELDS',
        message: 'volume_liters, amount_ksh and delivery_address are required',
      });
    }

    // Find nearest available verified driver
    const driversResult = await pool.query(
      `SELECT d.id, d.current_lat, d.current_lng, u.name, u.phone
       FROM drivers AS d
       INNER JOIN users AS u ON d.user_id = u.id
       WHERE d.is_available = true AND d.is_verified = true
         AND d.current_lat IS NOT NULL AND d.current_lng IS NOT NULL`
    );

    let assignedDriver = null;

    if (driversResult.rows.length > 0 && delivery_lat) {
      const withDistance = driversResult.rows.map((driver) => {
        const dLat = (driver.current_lat - delivery_lat) * (Math.PI / 180);
        const dLng = (driver.current_lng - delivery_lng) * (Math.PI / 180);
        const a =
          Math.sin(dLat / 2) * Math.sin(dLat / 2) +
          Math.cos(delivery_lat * (Math.PI / 180)) *
            Math.cos(driver.current_lat * (Math.PI / 180)) *
            Math.sin(dLng / 2) * Math.sin(dLng / 2);
        return { ...driver, distance_km: 6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a)) };
      });
      withDistance.sort((a, b) => a.distance_km - b.distance_km);
      assignedDriver = withDistance[0];
    }

    const result = await pool.query(
      `INSERT INTO orders
         (user_id, driver_id, product_id, volume_liters, amount_ksh,
          delivery_fee,
          delivery_address, delivery_lat, delivery_lng, status, notes,
          quantity, return_empties)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)
       RETURNING *`,
      [
        user_id,
        assignedDriver ? assignedDriver.id : null,
        product_id || null,
        volume_liters,
        amount_ksh,
        delivery_fee != null ? parseFloat(delivery_fee) : 60,
        delivery_address,
        delivery_lat || null,
        delivery_lng || null,
        assignedDriver ? 'ASSIGNED' : 'PENDING',
        notes || null,
        quantity != null ? parseInt(quantity, 10) : 1,
        return_empties === true || return_empties === 'true',
      ]
    );

    const order = result.rows[0];

    // Mark assigned driver as on_delivery and log initial status
    if (assignedDriver) {
      await pool.query(
        `UPDATE drivers SET status = 'on_delivery', is_available = false WHERE id = $1`,
        [assignedDriver.id]
      );
      await pool.query(
        `INSERT INTO order_status_log (order_id, status, changed_by) VALUES ($1, 'ASSIGNED', $2)`,
        [order.id, user_id]
      );
      const { getIo } = require('../config/socket');
      const io = getIo();
      if (io) io.to('admin-room').emit('driver:status', { driverId: assignedDriver.id, status: 'on_delivery' });
    }

    return res.status(201).json({
      message: assignedDriver
        ? `Order placed and assigned to driver ${assignedDriver.name}`
        : 'Order placed. Waiting for an available driver.',
      order,
      assigned_driver: assignedDriver
        ? {
            name: assignedDriver.name,
            phone: assignedDriver.phone,
            distance_km: parseFloat(assignedDriver.distance_km.toFixed(2)),
          }
        : null,
    });
  } catch (error) {
    console.error('Create order error:', error.message);
    return res.status(500).json({ error: 'SERVER_ERROR', message: 'Something went wrong.' });
  }
};

// GET /api/orders — Get my orders (resident)
const getMyOrders = async (req, res) => {
  try {
    const user_id = req.user.id;
    const result = await pool.query(
      `SELECT o.*,
              p.name AS product_name,
              u.name AS driver_name,
              u.phone AS driver_phone
       FROM orders AS o
       LEFT JOIN products AS p ON o.product_id = p.id
       LEFT JOIN drivers AS d ON o.driver_id = d.id
       LEFT JOIN users AS u ON d.user_id = u.id
       WHERE o.user_id = $1
       ORDER BY o.created_at DESC`,
      [user_id]
    );
    return res.status(200).json({ count: result.rows.length, orders: result.rows });
  } catch (error) {
    console.error('Get orders error:', error.message);
    return res.status(500).json({ error: 'SERVER_ERROR', message: 'Something went wrong.' });
  }
};

// GET /api/orders/:id — Get one order
const getOrderById = async (req, res) => {
  try {
    const { id } = req.params;
    const user_id = req.user.id;
    const role = req.user.role;

    const query =
      role === 'admin'
        ? `SELECT o.*, p.name AS product_name, cu.name AS customer_name, cu.phone AS customer_phone,
                  du.name AS driver_name, du.phone AS driver_phone,
                  d.rating AS driver_rating, d.vehicle_info AS driver_vehicle_info,
                  d.vehicle_plate AS driver_vehicle_plate,
                  pod.photo_url AS pod_photo_url, pod.signature_url AS pod_signature_url,
                  pod.empty_collected AS pod_empty_collected, pod.notes AS pod_notes
           FROM orders AS o
           LEFT JOIN products AS p ON o.product_id = p.id
           LEFT JOIN users AS cu ON o.user_id = cu.id
           LEFT JOIN drivers AS d ON o.driver_id = d.id
           LEFT JOIN users AS du ON d.user_id = du.id
           LEFT JOIN proof_of_delivery AS pod ON pod.order_id = o.id
           WHERE o.id = $1`
        : `SELECT o.*, p.name AS product_name, du.name AS driver_name, du.phone AS driver_phone,
                  d.rating AS driver_rating, d.vehicle_info AS driver_vehicle_info,
                  d.vehicle_plate AS driver_vehicle_plate,
                  pod.photo_url AS pod_photo_url, pod.signature_url AS pod_signature_url,
                  pod.empty_collected AS pod_empty_collected, pod.notes AS pod_notes
           FROM orders AS o
           LEFT JOIN products AS p ON o.product_id = p.id
           LEFT JOIN drivers AS d ON o.driver_id = d.id
           LEFT JOIN users AS du ON d.user_id = du.id
           LEFT JOIN proof_of_delivery AS pod ON pod.order_id = o.id
           WHERE o.id = $1 AND o.user_id = $2`;

    const params = role === 'admin' ? [id] : [id, user_id];
    const result = await pool.query(query, params);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'ORDER_NOT_FOUND', message: 'Order not found' });
    }
    return res.status(200).json({ order: result.rows[0] });
  } catch (error) {
    console.error('Get order error:', error.message);
    return res.status(500).json({ error: 'SERVER_ERROR', message: 'Something went wrong.' });
  }
};

// PUT /api/orders/:id/status — Update order status
const updateOrderStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;

    const validStatuses = ['PENDING', 'PAID', 'ASSIGNED', 'IN_TRANSIT', 'DELIVERED', 'COMPLETED', 'CANCELLED'];
    if (!validStatuses.includes(status)) {
      return res.status(400).json({
        error: 'INVALID_STATUS',
        message: `Status must be one of: ${validStatuses.join(', ')}`,
      });
    }

    const completed_at = ['DELIVERED', 'COMPLETED'].includes(status) ? new Date() : null;

    const result = await pool.query(
      `UPDATE orders SET status = $1, completed_at = COALESCE($2, completed_at)
       WHERE id = $3 RETURNING *`,
      [status, completed_at, id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'ORDER_NOT_FOUND', message: 'Order not found' });
    }

    const order = result.rows[0];

    // Free driver when order reaches a terminal state
    if (['DELIVERED', 'COMPLETED', 'CANCELLED'].includes(status) && order.driver_id) {
      const others = await pool.query(
        `SELECT id FROM orders WHERE driver_id = $1 AND status IN ('ASSIGNED','IN_TRANSIT') AND id != $2`,
        [order.driver_id, id]
      );
      if (others.rows.length === 0) {
        await pool.query(
          `UPDATE drivers SET status = 'available', is_available = true WHERE id = $1`,
          [order.driver_id]
        );
        const { getIo } = require('../config/socket');
        const io = getIo();
        if (io) io.to('admin-room').emit('driver:status', { driverId: order.driver_id, status: 'available' });
      }
    }

    return res.status(200).json({ message: `Order status updated to ${status}`, order });
  } catch (error) {
    console.error('Update order status error:', error.message);
    return res.status(500).json({ error: 'SERVER_ERROR', message: 'Something went wrong.' });
  }
};

// POST /api/orders/:id/rate — Rate an order the resident has confirmed as received.
// Gated on status = 'COMPLETED' (set via POST /api/quality/orders/:id/verify, the resident's
// "confirm receipt" action) rather than 'DELIVERED' alone, and rejects a second rating.
const rateOrder = async (req, res) => {
  try {
    const { id } = req.params;
    const { rating } = req.body;
    const user_id = req.user.id;

    if (!rating || rating < 1 || rating > 5) {
      return res.status(400).json({ error: 'INVALID_RATING', message: 'Rating must be 1–5' });
    }

    const result = await pool.query(
      `UPDATE orders SET rating = $1
       WHERE id = $2 AND user_id = $3 AND status = 'COMPLETED' AND rating IS NULL
       RETURNING *`,
      [rating, id, user_id]
    );

    if (result.rows.length === 0) {
      const check = await pool.query(
        `SELECT status, rating FROM orders WHERE id = $1 AND user_id = $2`,
        [id, user_id]
      );
      if (check.rows.length === 0) {
        return res.status(404).json({
          error: 'NOT_FOUND',
          message: 'Order not found or does not belong to you',
        });
      }
      if (check.rows[0].rating != null) {
        return res.status(409).json({ error: 'ALREADY_RATED', message: 'This order has already been rated' });
      }
      return res.status(400).json({
        error: 'NOT_ELIGIBLE',
        message: 'Confirm you have received this order before rating it',
      });
    }
    return res.status(200).json({ message: 'Rating saved. Thank you!', order: result.rows[0] });
  } catch (error) {
    console.error('Rate order error:', error.message);
    return res.status(500).json({ error: 'SERVER_ERROR', message: 'Something went wrong.' });
  }
};

// DELETE /api/orders/:id — Cancel order
const cancelOrder = async (req, res) => {
  try {
    const { id } = req.params;
    const user_id = req.user.id;

    const result = await pool.query(
      `UPDATE orders SET status = 'CANCELLED'
       WHERE id = $1 AND user_id = $2 AND status IN ('PENDING', 'ASSIGNED')
       RETURNING *`,
      [id, user_id]
    );

    if (result.rows.length === 0) {
      return res.status(400).json({
        error: 'CANNOT_CANCEL',
        message: 'Order not found or cannot be cancelled at this stage',
      });
    }
    return res.status(200).json({ message: 'Order cancelled successfully', order: result.rows[0] });
  } catch (error) {
    console.error('Cancel order error:', error.message);
    return res.status(500).json({ error: 'SERVER_ERROR', message: 'Something went wrong.' });
  }
};

// GET /api/orders/driver — Orders assigned to logged-in driver
const getDriverOrders = async (req, res) => {
  try {
    const user_id = req.user.id;

    // Ensure driver profile exists (handles legacy accounts)
    await pool.query(
      `INSERT INTO drivers (user_id, vehicle_plate, status, is_available, is_verified)
       VALUES ($1, 'TBD', 'offline', false, false)
       ON CONFLICT (user_id) DO NOTHING`,
      [user_id]
    );

    const driverResult = await pool.query('SELECT id FROM drivers WHERE user_id = $1', [user_id]);

    if (driverResult.rows.length === 0) {
      return res.status(404).json({ error: 'DRIVER_NOT_FOUND', message: 'No driver profile found' });
    }

    const driver_id = driverResult.rows[0].id;

    const result = await pool.query(
      `SELECT o.*,
              p.name AS product_name,
              cu.name AS customer_name,
              cu.phone AS customer_phone
       FROM orders AS o
       LEFT JOIN products AS p ON o.product_id = p.id
       INNER JOIN users AS cu ON o.user_id = cu.id
       WHERE o.driver_id = $1
       ORDER BY o.created_at DESC`,
      [driver_id]
    );

    return res.status(200).json({ count: result.rows.length, orders: result.rows });
  } catch (error) {
    console.error('Get driver orders error:', error.message);
    return res.status(500).json({ error: 'SERVER_ERROR', message: 'Something went wrong.' });
  }
};

// GET /api/orders/admin/all — All orders (admin only)
const getAllOrdersAdmin = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT o.*,
              p.name AS product_name,
              cu.name AS customer_name,
              cu.phone AS customer_phone,
              du.name AS driver_name,
              du.phone AS driver_phone,
              pod.photo_url AS pod_photo_url,
              pod.signature_url AS pod_signature_url,
              pod.empty_collected AS pod_empty_collected
       FROM orders o
       LEFT JOIN products p ON o.product_id = p.id
       INNER JOIN users cu ON o.user_id = cu.id
       LEFT JOIN drivers d ON o.driver_id = d.id
       LEFT JOIN users du ON d.user_id = du.id
       LEFT JOIN proof_of_delivery pod ON pod.order_id = o.id
       ORDER BY o.created_at DESC`
    );

    const orders = result.rows;
    const totalRevenue = orders
      .filter((o) => ['DELIVERED', 'COMPLETED'].includes(o.status))
      .reduce((sum, o) => sum + (parseFloat(o.amount_ksh) || 0), 0);

    return res.status(200).json({
      count: orders.length,
      orders,
      stats: {
        total: orders.length,
        pending: orders.filter((o) => o.status === 'PENDING').length,
        active: orders.filter((o) => ['ASSIGNED', 'IN_TRANSIT'].includes(o.status)).length,
        delivered: orders.filter((o) => o.status === 'DELIVERED').length,
        completed: orders.filter((o) => o.status === 'COMPLETED').length,
        cancelled: orders.filter((o) => o.status === 'CANCELLED').length,
        totalRevenue,
      },
    });
  } catch (error) {
    console.error('Get all orders admin error:', error.message);
    return res.status(500).json({ error: 'SERVER_ERROR', message: 'Something went wrong.' });
  }
};

// PUT /api/orders/:id/assign — Assign driver (admin only)
const assignDriver = async (req, res) => {
  try {
    const { id } = req.params;
    const { driver_id } = req.body;

    if (!driver_id) {
      return res.status(400).json({ error: 'MISSING_FIELDS', message: 'driver_id is required' });
    }

    const orderResult = await pool.query('SELECT * FROM orders WHERE id = $1', [id]);
    if (orderResult.rows.length === 0) {
      return res.status(404).json({ error: 'ORDER_NOT_FOUND', message: 'Order not found' });
    }

    if (!['PENDING', 'PAID'].includes(orderResult.rows[0].status)) {
      return res.status(400).json({ error: 'INVALID_STATUS', message: 'Only PENDING or PAID orders can be assigned' });
    }

    const driverResult = await pool.query(
      `SELECT d.*, u.name, u.phone FROM drivers d INNER JOIN users u ON d.user_id = u.id WHERE d.id = $1`,
      [driver_id]
    );

    if (driverResult.rows.length === 0) {
      return res.status(404).json({ error: 'DRIVER_NOT_FOUND', message: 'Driver not found' });
    }

    const driver = driverResult.rows[0];
    const result = await pool.query(
      `UPDATE orders SET driver_id = $1, status = 'ASSIGNED' WHERE id = $2 RETURNING *`,
      [driver_id, id]
    );

    // Mark driver as on_delivery and log status change
    await pool.query(
      `UPDATE drivers SET status = 'on_delivery', is_available = false WHERE id = $1`,
      [driver_id]
    );
    await pool.query(
      `INSERT INTO order_status_log (order_id, status, changed_by) VALUES ($1, 'ASSIGNED', $2)`,
      [id, req.user.id]
    );
    const { getIo } = require('../config/socket');
    const io = getIo();
    if (io) io.to('admin-room').emit('driver:status', { driverId: driver_id, status: 'on_delivery' });

    return res.status(200).json({
      message: `Order assigned to ${driver.name}`,
      order: result.rows[0],
      driver: { id: driver.id, name: driver.name, phone: driver.phone },
    });
  } catch (error) {
    console.error('Assign driver error:', error.message);
    return res.status(500).json({ error: 'SERVER_ERROR', message: 'Something went wrong.' });
  }
};

// GET /api/orders/:id/tracking — lightweight polling endpoint for resident tracking screen
const getOrderTracking = async (req, res) => {
  try {
    const { id } = req.params;
    const user_id = req.user.id;
    const role = req.user.role;

    const whereClause = role === 'admin' ? 'WHERE o.id = $1' : 'WHERE o.id = $1 AND o.user_id = $2';
    const params = role === 'admin' ? [id] : [id, user_id];

    const result = await pool.query(
      `SELECT o.id, o.status, o.delivery_lat, o.delivery_lng, o.delivery_address,
              o.created_at, o.completed_at,
              dr.current_lat, dr.current_lng, dr.location_updated_at,
              du.name AS driver_name, du.phone AS driver_phone,
              dr.vehicle_plate, dr.vehicle_info, dr.rating AS driver_rating,
              osl.status AS last_logged_status, osl.changed_at AS last_status_at
       FROM orders o
       LEFT JOIN drivers dr ON o.driver_id = dr.id
       LEFT JOIN users du   ON dr.user_id = du.id
       LEFT JOIN LATERAL (
         SELECT status, changed_at
         FROM order_status_log
         WHERE order_id = o.id
         ORDER BY changed_at DESC
         LIMIT 1
       ) osl ON true
       ${whereClause}`,
      params
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'ORDER_NOT_FOUND', message: 'Order not found' });
    }

    const row = result.rows[0];
    return res.status(200).json({
      tracking: {
        order_id: row.id,
        status: row.status,
        delivery_lat: row.delivery_lat ? parseFloat(row.delivery_lat) : null,
        delivery_lng: row.delivery_lng ? parseFloat(row.delivery_lng) : null,
        delivery_address: row.delivery_address,
        driver: row.driver_name
          ? {
              name: row.driver_name,
              phone: row.driver_phone,
              vehicle_plate: row.vehicle_plate,
              vehicle_info: row.vehicle_info,
              rating: row.driver_rating,
              current_lat: row.current_lat ? parseFloat(row.current_lat) : null,
              current_lng: row.current_lng ? parseFloat(row.current_lng) : null,
              location_updated_at: row.location_updated_at,
            }
          : null,
        last_status_change: row.last_logged_status
          ? { status: row.last_logged_status, at: row.last_status_at }
          : null,
      },
    });
  } catch (error) {
    console.error('Get order tracking error:', error.message);
    return res.status(500).json({ error: 'SERVER_ERROR', message: 'Something went wrong.' });
  }
};

module.exports = {
  createOrder,
  getMyOrders,
  getOrderById,
  updateOrderStatus,
  rateOrder,
  cancelOrder,
  getDriverOrders,
  getAllOrdersAdmin,
  assignDriver,
  getOrderTracking,
};
