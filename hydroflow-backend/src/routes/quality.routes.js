const express = require('express');
const {
  verifyQuality,
  getQualityReport
} = require('../controllers/qualityController');
const { protect } = require('../middleware/authMiddleware');
const { allowRoles } = require('../middleware/roleMiddleware');

const router = express.Router();

// POST /api/quality/orders/:id/verify - Resident confirms receipt of a DELIVERED order
router.post('/orders/:id/verify', protect, allowRoles('resident'), verifyQuality);

// GET /api/quality/orders/:id/report - Returns quality report for an order
router.get('/orders/:id/report', protect, getQualityReport);

module.exports = router;