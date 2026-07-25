const express = require('express');
const { sendOrderSMS, sendCustomSMS } = require('../controllers/notificationController');
const { protect } = require('../middleware/authMiddleware');
const { allowRoles } = require('../middleware/roleMiddleware');

const router = express.Router();

router.post('/order/:id/status-sms', protect, allowRoles('admin'), sendOrderSMS);
router.post('/sms', protect, allowRoles('admin'), sendCustomSMS);

module.exports = router;
