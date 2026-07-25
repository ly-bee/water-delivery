const express = require('express');
const {
  createOrder,
  getMyOrders,
  getOrderById,
  getDriverOrders,
  getAllOrdersAdmin,
  assignDriver,
  updateOrderStatus,
  rateOrder,
  cancelOrder,
  getOrderTracking,
} = require('../controllers/orderController');
const { protect } = require('../middleware/authMiddleware');
const { allowRoles } = require('../middleware/roleMiddleware');

const router = express.Router();

router.post('/', protect, allowRoles('resident', 'admin'), createOrder);
router.get('/', protect, allowRoles('resident'), getMyOrders);
router.get('/driver', protect, allowRoles('driver'), getDriverOrders);
router.get('/admin/all', protect, allowRoles('admin'), getAllOrdersAdmin);
router.get('/:id/tracking', protect, getOrderTracking);
router.get('/:id', protect, getOrderById);
router.put('/:id/assign', protect, allowRoles('admin'), assignDriver);
router.put('/:id/status', protect, allowRoles('driver', 'admin'), updateOrderStatus);
router.post('/:id/rate', protect, allowRoles('resident'), rateOrder);
router.post('/:id/cancel', protect, allowRoles('resident', 'admin'), cancelOrder);
router.delete('/:id', protect, allowRoles('resident', 'admin'), cancelOrder);

module.exports = router;
