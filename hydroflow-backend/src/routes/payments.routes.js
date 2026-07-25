const express = require('express');
const {
  initiatePayment,
  mpesaCallback,
  checkPaymentStatus,
} = require('../controllers/mpesaController');
const { protect } = require('../middleware/authMiddleware');

const router = express.Router();

// POST /api/payments/mpesa/stkpush — trigger STK push (spec path)
router.post('/mpesa/stkpush', protect, initiatePayment);

// POST /api/payments/mpesa/callback — Safaricom callback (no auth)
router.post('/mpesa/callback', mpesaCallback);

// GET /api/payments/mpesa/status/:orderId — check payment status
router.get('/mpesa/status/:orderId', protect, checkPaymentStatus);

module.exports = router;
