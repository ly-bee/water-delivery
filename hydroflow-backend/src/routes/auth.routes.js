const express = require('express');
const {
  register,
  login,
  verifyEmail,
  resendVerification,
  sendOtp,
  verifyOtp,
  requestOtp,
  getProfile,
} = require('../controllers/authController');
const { protect } = require('../middleware/authMiddleware');

const router = express.Router();

// POST /api/auth/register
router.post('/register', register);

// POST /api/auth/login
router.post('/login', login);

// GET /api/auth/verify-email?token=xxx
router.get('/verify-email', verifyEmail);

// POST /api/auth/resend-verification
router.post('/resend-verification', resendVerification);

// POST /api/auth/send-otp
router.post('/send-otp', sendOtp);

// POST /api/auth/request-otp (spec alias)
router.post('/request-otp', requestOtp);

// POST /api/auth/verify-otp
router.post('/verify-otp', verifyOtp);

// GET /api/auth/profile
router.get('/profile', protect, getProfile);

module.exports = router;