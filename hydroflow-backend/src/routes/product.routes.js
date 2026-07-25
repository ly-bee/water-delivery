const express = require('express');
const { getProducts, createProduct, updateProduct } = require('../controllers/productController');
const { protect } = require('../middleware/authMiddleware');
const { allowRoles } = require('../middleware/roleMiddleware');

const router = express.Router();

router.get('/', protect, getProducts);
router.post('/', protect, allowRoles('admin'), createProduct);
router.put('/:id', protect, allowRoles('admin'), updateProduct);

module.exports = router;
