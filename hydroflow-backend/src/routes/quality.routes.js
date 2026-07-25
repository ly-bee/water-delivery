const express = require('express');
const {
  verifyQuality,
  getQualityReport
} = require('../controllers/qualityController');
const { protect } = require('../middleware/authMiddleware');

const router = express.Router();

// POST /api/quality/orders/:id/verify - Triggers quality check after delivery
router.post('/orders/:id/verify', protect, verifyQuality);

// GET /api/quality/orders/:id/report - Returns quality report for an order
router.get('/orders/:id/report', protect, getQualityReport);

module.exports = router;