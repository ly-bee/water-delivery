const express = require('express');
const multer = require('multer');
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

// Proof-of-delivery photo/signature — held in memory just long enough to stream to Cloudinary
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 8 * 1024 * 1024 }, // 8MB per file
});

// All /api/driver/* routes require JWT + driver role
router.use(protect, allowRoles('driver'));

router.get('/deliveries',              getDeliveries);
router.get('/deliveries/:id',          getDeliveryById);
router.patch('/deliveries/:id/status', updateDeliveryStatus);
router.post(
  '/deliveries/:id/proof',
  upload.fields([{ name: 'photo', maxCount: 1 }, { name: 'signature', maxCount: 1 }]),
  submitProof
);
router.patch('/location',              updateDriverLocation);
router.patch('/status',                updateDriverStatus);
router.get('/earnings',                getEarnings);

module.exports = router;
