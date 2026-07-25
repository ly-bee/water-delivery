const express = require('express');
const {
  initiatePayment,
  mpesaCallback,
  checkPaymentStatus,
} = require('../controllers/mpesaController');
const { protect } = require('../middleware/authMiddleware');

const router = express.Router();

// POST /api/mpesa/pay — trigger STK push (JWT protected)
router.post('/pay', protect, initiatePayment);

// POST /api/mpesa/callback — Safaricom calls this (no auth)
router.post('/callback', mpesaCallback);

// GET /api/mpesa/status/:orderId — check payment status (JWT protected)
router.get('/status/:orderId', protect, checkPaymentStatus);

module.exports = router;