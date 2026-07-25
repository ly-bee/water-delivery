const express = require('express');
const { getStats } = require('../controllers/adminController');
const {
  getAllOrdersAdmin,
  assignDriver,
} = require('../controllers/orderController');
const { protect } = require('../middleware/authMiddleware');
const { allowRoles } = require('../middleware/roleMiddleware');

const router = express.Router();

// All /api/admin/* routes require JWT + admin role
router.use(protect, allowRoles('admin'));

router.get('/stats',               getStats);
router.get('/orders',              getAllOrdersAdmin);
router.patch('/orders/:id/assign', assignDriver);

module.exports = router;
