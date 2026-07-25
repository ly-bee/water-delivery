const { sendSMS, sendOrderStatusSMS } = require('../services/notificationService');
const { pool } = require('../config/db');

// POST /api/notifications/order/:id/status-sms
// Manually trigger an order status SMS (admin use)
const sendOrderSMS = async (req, res) => {
  try {
    const { id } = req.params;

    const result = await pool.query(
      `SELECT o.*, u.name AS customer_name, u.phone AS customer_phone,
              du.name AS driver_name
       FROM orders o
       INNER JOIN users u ON o.user_id = u.id
       LEFT JOIN drivers d ON o.driver_id = d.id
       LEFT JOIN users du ON d.user_id = du.id
       WHERE o.id = $1`,
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'ORDER_NOT_FOUND', message: 'Order not found' });
    }

    const order = result.rows[0];

    const smsResult = await sendOrderStatusSMS({
      customerPhone: order.customer_phone,
      customerName: order.customer_name,
      status: order.status,
      volumeLiters: order.volume_liters,
      driverName: order.driver_name || 'our driver',
    });

    return res.status(200).json({
      message: smsResult.success ? 'SMS sent successfully' : 'SMS failed',
      sms: smsResult,
    });
  } catch (error) {
    console.error('Send order SMS error:', error.message);
    return res.status(500).json({ error: 'SERVER_ERROR', message: 'Something went wrong.' });
  }
};

// POST /api/notifications/sms — send a custom SMS (admin use)
const sendCustomSMS = async (req, res) => {
  try {
    const { phone, message } = req.body;

    if (!phone || !message) {
      return res.status(400).json({ error: 'MISSING_FIELDS', message: 'phone and message are required' });
    }

    const result = await sendSMS(phone, message);

    return res.status(200).json({
      message: result.success ? 'SMS sent' : 'SMS failed',
      result,
    });
  } catch (error) {
    console.error('Send custom SMS error:', error.message);
    return res.status(500).json({ error: 'SERVER_ERROR', message: 'Something went wrong.' });
  }
};

module.exports = { sendOrderSMS, sendCustomSMS };
