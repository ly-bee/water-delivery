const express = require('express');
const {
  getDeliveries,
  getDeliveryById,
  updateDeliveryStatus,
  submitProof,
  updateDriverLocation,
  updateDriverStatus,
  getEarnings,
} = require('../controllers/driverSelfController');
const { protect } = require('../middleware/authMiddleware');
const { allowRoles } = require('../middleware/roleMiddleware');

const router = express.Router();

// All /api/driver/* routes require JWT + driver role
router.use(protect, allowRoles('driver'));

router.get('/deliveries',              getDeliveries);
router.get('/deliveries/:id',          getDeliveryById);
router.patch('/deliveries/:id/status', updateDeliveryStatus);
router.post('/deliveries/:id/proof',   submitProof);
router.patch('/location',              updateDriverLocation);
router.patch('/status',                updateDriverStatus);
router.get('/earnings',                getEarnings);

module.exports = router;
