const { pool } = require('../config/db');
const { initiateSTKPush } = require('../services/mpesaService');

// POST /api/mpesa/pay
// Initiates STK Push for an order
const initiatePayment = async (req, res) => {
  try {
    const { order_id } = req.body;
    const userId = req.user.id;

    if (!order_id) {
      return res.status(400).json({
        error: 'MISSING_FIELDS',
        message: 'order_id is required',
      });
    }

    // Get order details
    const orderResult = await pool.query(
      `SELECT o.*, COALESCE(p.name, 'Water Delivery') AS product_name, u.phone
       FROM orders o
       LEFT JOIN products p ON o.product_id = p.id
       INNER JOIN users u ON o.user_id = u.id
       WHERE o.id = $1 AND o.user_id = $2`,
      [order_id, userId]
    );

    if (orderResult.rows.length === 0) {
      return res.status(404).json({
        error: 'ORDER_NOT_FOUND',
        message: 'Order not found',
      });
    }

    const order = orderResult.rows[0];

    // Only PENDING orders can be paid
    if (order.status !== 'PENDING') {
      return res.status(400).json({
        error: 'INVALID_STATUS',
        message: `Order is already ${order.status}. Only PENDING orders can be paid.`,
      });
    }

    // Initiate STK Push
    const stkResponse = await initiateSTKPush({
      phone: order.phone,
      amount: order.amount_ksh,
      orderId: order.id,
      productName: order.product_name,
    });

    // Save checkout request ID for callback matching
    await pool.query(
      `UPDATE orders 
       SET mpesa_checkout_id = $1 
       WHERE id = $2`,
      [stkResponse.CheckoutRequestID, order_id]
    );

    return res.status(200).json({
      message: 'STK Push sent. Please check your phone and enter your M-Pesa PIN.',
      checkout_request_id: stkResponse.CheckoutRequestID,
      merchant_request_id: stkResponse.MerchantRequestID,
    });
  } catch (error) {
    console.error('Initiate payment error:', error.response?.data || error.message);
    return res.status(500).json({
      error: 'PAYMENT_FAILED',
      message: 'Failed to initiate payment. Please try again.',
    });
  }
};

// POST /api/mpesa/callback
// Safaricom calls this after payment
const mpesaCallback = async (req, res) => {
  try {
    const { Body } = req.body;
    const { stkCallback } = Body;

    const { ResultCode, CheckoutRequestID, CallbackMetadata } = stkCallback;

    // Find order by checkout request ID
    const orderResult = await pool.query(
      'SELECT * FROM orders WHERE mpesa_checkout_id = $1',
      [CheckoutRequestID]
    );

    if (orderResult.rows.length === 0) {
      return res.status(200).json({ message: 'Order not found' });
    }

    const order = orderResult.rows[0];

    if (ResultCode === 0) {
      // Payment successful — extract M-Pesa receipt
      const items = CallbackMetadata?.Item || [];
      const receipt = items.find((i) => i.Name === 'MpesaReceiptNumber')?.Value;
      const amount = items.find((i) => i.Name === 'Amount')?.Value;

      // Update order to PAID
      await pool.query(
        `UPDATE orders 
         SET status = 'PAID', 
             mpesa_receipt = $1,
             paid_at = NOW()
         WHERE id = $2`,
        [receipt, order.id]
      );

      console.log(`✅ Payment confirmed for order ${order.id} — Receipt: ${receipt} — KSh ${amount}`);
    } else {
      // Payment failed or cancelled
      console.log(`❌ Payment failed for order ${order.id} — Code: ${ResultCode}`);
    }

    // Always respond 200 to Safaricom
    return res.status(200).json({ ResultCode: 0, ResultDesc: 'Success' });
  } catch (error) {
    console.error('M-Pesa callback error:', error.message);
    return res.status(200).json({ ResultCode: 0, ResultDesc: 'Success' });
  }
};

// GET /api/mpesa/status/:orderId
// Check payment status of an order
const checkPaymentStatus = async (req, res) => {
  try {
    const { orderId } = req.params;
    const userId = req.user.id;

    const result = await pool.query(
      `SELECT id, status, mpesa_receipt, amount_ksh, paid_at
       FROM orders 
       WHERE id = $1 AND user_id = $2`,
      [orderId, userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        error: 'ORDER_NOT_FOUND',
        message: 'Order not found',
      });
    }

    const order = result.rows[0];

    return res.status(200).json({
      order_id: order.id,
      status: order.status,
      mpesa_receipt: order.mpesa_receipt,
      amount_ksh: order.amount_ksh,
      paid_at: order.paid_at,
    });
  } catch (error) {
    console.error('Check payment status error:', error.message);
    return res.status(500).json({
      error: 'SERVER_ERROR',
      message: 'Something went wrong.',
    });
  }
};

module.exports = { initiatePayment, mpesaCallback, checkPaymentStatus };