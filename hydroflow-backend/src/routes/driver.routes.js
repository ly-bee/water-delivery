const express = require('express');
const {
  registerDriver,
  updateLocation,
  toggleAvailability,
  updateDriverStatusSelf,
  getNearbyDrivers,
  getAllDriversAdmin,
  getDriverLocations,
  getDriverDetailAdmin,
  verifyDriver,
  updateDriverStatusAdmin,
  reassignOrderAdmin,
} = require('../controllers/driverController');
const { protect }    = require('../middleware/authMiddleware');
const { allowRoles } = require('../middleware/roleMiddleware');

const router = express.Router();

/* ── driver self-service ─────────────────────────────────────────────────── */
router.post   ('/register',     protect, allowRoles('driver', 'admin'), registerDriver);
router.put    ('/location',     protect, allowRoles('driver'),          updateLocation);
router.put    ('/availability', protect, allowRoles('driver'),          toggleAvailability);  // legacy
router.patch  ('/status',       protect, allowRoles('driver'),          updateDriverStatusSelf);

/* ── shared ──────────────────────────────────────────────────────────────── */
router.get    ('/nearby',       protect, getNearbyDrivers);

/* ── admin ───────────────────────────────────────────────────────────────── */
// Note: static paths (/admin/all, /admin/locations) MUST come before /:id patterns
router.get    ('/admin/all',        protect, allowRoles('admin'), getAllDriversAdmin);
router.get    ('/admin/locations',  protect, allowRoles('admin'), getDriverLocations);
router.get    ('/admin/:id',        protect, allowRoles('admin'), getDriverDetailAdmin);
router.patch  ('/admin/:id/status', protect, allowRoles('admin'), updateDriverStatusAdmin);
router.patch  ('/admin/:id/reassign', protect, allowRoles('admin'), reassignOrderAdmin);
router.put    ('/:id/verify',      protect, allowRoles('admin'), verifyDriver);

module.exports = router;
