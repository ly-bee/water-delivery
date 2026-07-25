const express = require('express');
const { getAllUsers, getMe, updateMe } = require('../controllers/userController');
const { protect } = require('../middleware/authMiddleware');
const { allowRoles } = require('../middleware/roleMiddleware');

const router = express.Router();

router.get('/me', protect, getMe);
router.put('/me', protect, updateMe);
router.get('/', protect, allowRoles('admin'), getAllUsers);

module.exports = router;
