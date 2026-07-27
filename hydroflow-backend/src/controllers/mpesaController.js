const { pool } = require('../config/db');
const { initiateSTKPush } = require('../services/mpesaService');

// POST /api/mpesa/pay
// Initiates STK Push for an order
const initiatePayment = async (req, res) => {
  try {
    const { order_id, phone } = req.body;
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

    // Already paid, or too far along / cancelled — nothing left to pay for
    if (order.mpesa_receipt) {
      return res.status(400).json({
        error: 'ALREADY_PAID',
        message: 'This order has already been paid for.',
      });
    }
    // A driver can already be auto-assigned at creation time (see orderController.createOrder),
    // so PENDING and ASSIGNED both still need to accept payment — not just PENDING.
    if (!['PENDING', 'ASSIGNED'].includes(order.status)) {
      return res.status(400).json({
        error: 'INVALID_STATUS',
        message: `Order is ${order.status} and can no longer be paid.`,
      });
    }

    // Initiate STK Push — honor a phone entered at checkout, fall back to the account phone
    const stkResponse = await initiateSTKPush({
      phone: phone || order.phone,
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

      // Record the payment. Only move status to PAID if the order was still PENDING —
      // if a driver was already auto-assigned (order is ASSIGNED/IN_TRANSIT), paying for it
      // must not clobber that delivery-progress status back down to PAID.
      await pool.query(
        `UPDATE orders
         SET status = CASE WHEN status = 'PENDING' THEN 'PAID' ELSE status END,
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

// POST /api/mpesa/confirm
// Resident manually confirms they've completed the M-Pesa payment on their phone.
// Used instead of waiting on Safaricom's callback, which requires a public callback URL
// that isn't always reliably reachable from a local/dev setup — this makes checkout not
// depend on that. Self-reported: mpesa_receipt holds the code the resident typed in from
// their M-Pesa SMS if they gave one, or a clearly-flagged placeholder if they didn't.
const confirmPaymentManually = async (req, res) => {
  try {
    const { order_id, mpesa_code } = req.body;
    const userId = req.user.id;

    if (!order_id) {
      return res.status(400).json({
        error: 'MISSING_FIELDS',
        message: 'order_id is required',
      });
    }

    const orderResult = await pool.query(
      `SELECT * FROM orders WHERE id = $1 AND user_id = $2`,
      [order_id, userId]
    );

    if (orderResult.rows.length === 0) {
      return res.status(404).json({
        error: 'ORDER_NOT_FOUND',
        message: 'Order not found',
      });
    }

    const order = orderResult.rows[0];

    if (order.mpesa_receipt) {
      return res.status(400).json({
        error: 'ALREADY_PAID',
        message: 'This order has already been marked as paid.',
      });
    }
    if (!['PENDING', 'ASSIGNED'].includes(order.status)) {
      return res.status(400).json({
        error: 'INVALID_STATUS',
        message: `Order is ${order.status} and can no longer be paid.`,
      });
    }

    const receiptValue = mpesa_code && mpesa_code.trim() ? mpesa_code.trim() : 'RESIDENT_CONFIRMED';

    // Same safe transition as the callback — only move PENDING to PAID, never clobber an
    // already-assigned order's delivery-progress status.
    const result = await pool.query(
      `UPDATE orders
       SET status = CASE WHEN status = 'PENDING' THEN 'PAID' ELSE status END,
           mpesa_receipt = $1,
           paid_at = NOW()
       WHERE id = $2
       RETURNING *`,
      [receiptValue, order_id]
    );

    console.log(`✅ Payment self-confirmed by resident for order ${order_id} — code: ${receiptValue}`);

    return res.status(200).json({ message: 'Payment confirmed. Thank you!', order: result.rows[0] });
  } catch (error) {
    console.error('Confirm payment error:', error.message);
    return res.status(500).json({
      error: 'SERVER_ERROR',
      message: 'Something went wrong.',
    });
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

module.exports = { initiatePayment, mpesaCallback, checkPaymentStatus, confirmPaymentManually };