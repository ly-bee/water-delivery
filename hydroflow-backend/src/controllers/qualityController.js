const { pool } = require('../config/db');

// POST /api/quality/orders/:id/verify
// Resident's "confirm receipt" action — the step between a driver marking an order DELIVERED
// and the resident being allowed to rate it (no IoT TDS check anymore; name kept for now).
const verifyQuality = async (req, res) => {
  try {
    const { id } = req.params;
    const user_id = req.user.id;

    const orderResult = await pool.query(
      'SELECT * FROM orders WHERE id = $1 AND user_id = $2',
      [id, user_id]
    );

    if (orderResult.rows.length === 0) {
      return res.status(404).json({ error: 'ORDER_NOT_FOUND', message: 'Order not found or does not belong to you' });
    }

    const order = orderResult.rows[0];

    if (order.status !== 'DELIVERED') {
      return res.status(400).json({
        error: 'INVALID_STATUS',
        message: `Order must be delivered before you can confirm receipt. Current status: ${order.status}`,
      });
    }

    // completed_at already reflects when the driver delivered the order (set at the
    // DELIVERED transition) — leave it untouched here, it feeds driver earnings/revenue
    // reporting and shouldn't shift to whenever the resident happens to confirm.
    const result = await pool.query(
      `UPDATE orders SET status = 'COMPLETED' WHERE id = $1 RETURNING *`,
      [id]
    );

    return res.status(200).json({
      message: 'Delivery confirmed — you can now rate your order.',
      verdict: 'PASSED',
      order: result.rows[0],
    });
  } catch (error) {
    console.error('Verify quality error:', error.message);
    return res.status(500).json({ error: 'SERVER_ERROR', message: 'Something went wrong.' });
  }
};

// GET /api/quality/orders/:id/report
const getQualityReport = async (req, res) => {
  try {
    const { id } = req.params;
    const user_id = req.user.id;
    const role = req.user.role;

    const query =
      role === 'admin'
        ? 'SELECT * FROM orders WHERE id = $1'
        : 'SELECT * FROM orders WHERE id = $1 AND user_id = $2';
    const params = role === 'admin' ? [id] : [id, user_id];

    const result = await pool.query(query, params);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'ORDER_NOT_FOUND', message: 'Order not found' });
    }

    const order = result.rows[0];

    return res.status(200).json({
      order_id: order.id,
      status: order.status,
      delivery_address: order.delivery_address,
      rating: order.rating,
      amount_ksh: order.amount_ksh,
      created_at: order.created_at,
      completed_at: order.completed_at,
    });
  } catch (error) {
    console.error('Get quality report error:', error.message);
    return res.status(500).json({ error: 'SERVER_ERROR', message: 'Something went wrong.' });
  }
};

module.exports = { verifyQuality, getQualityReport };
