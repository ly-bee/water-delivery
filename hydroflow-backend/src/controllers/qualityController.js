const { pool } = require('../config/db');

// POST /api/quality/orders/:id/verify
// Marks a DELIVERED order as COMPLETED (no IoT TDS check anymore)
const verifyQuality = async (req, res) => {
  try {
    const { id } = req.params;

    const orderResult = await pool.query('SELECT * FROM orders WHERE id = $1', [id]);

    if (orderResult.rows.length === 0) {
      return res.status(404).json({ error: 'ORDER_NOT_FOUND', message: 'Order not found' });
    }

    const order = orderResult.rows[0];

    if (order.status !== 'DELIVERED') {
      return res.status(400).json({
        error: 'INVALID_STATUS',
        message: `Order must be DELIVERED before completing. Current status: ${order.status}`,
      });
    }

    const result = await pool.query(
      `UPDATE orders SET status = 'COMPLETED', completed_at = NOW() WHERE id = $1 RETURNING *`,
      [id]
    );

    return res.status(200).json({
      message: 'Order marked as completed',
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
