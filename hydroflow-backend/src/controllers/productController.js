const { pool } = require('../config/db');

// GET /api/products — list all active products
const getProducts = async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM products WHERE is_active = true ORDER BY volume_liters ASC'
    );
    return res.status(200).json({ products: result.rows });
  } catch (error) {
    console.error('Get products error:', error.message);
    return res.status(500).json({ error: 'SERVER_ERROR', message: 'Something went wrong.' });
  }
};

// POST /api/products — create product (admin only)
const createProduct = async (req, res) => {
  try {
    const { name, volume_liters, price_ksh, description } = req.body;
    if (!name || !volume_liters || !price_ksh) {
      return res.status(400).json({
        error: 'MISSING_FIELDS',
        message: 'name, volume_liters and price_ksh are required',
      });
    }
    const result = await pool.query(
      `INSERT INTO products (name, volume_liters, price_ksh, description)
       VALUES ($1, $2, $3, $4) RETURNING *`,
      [name, volume_liters, price_ksh, description || null]
    );
    return res.status(201).json({ product: result.rows[0] });
  } catch (error) {
    console.error('Create product error:', error.message);
    return res.status(500).json({ error: 'SERVER_ERROR', message: 'Something went wrong.' });
  }
};

// PUT /api/products/:id — update product (admin only)
const updateProduct = async (req, res) => {
  try {
    const { id } = req.params;
    const { name, volume_liters, price_ksh, description, is_active } = req.body;
    const result = await pool.query(
      `UPDATE products
       SET name = COALESCE($1, name),
           volume_liters = COALESCE($2, volume_liters),
           price_ksh = COALESCE($3, price_ksh),
           description = COALESCE($4, description),
           is_active = COALESCE($5, is_active)
       WHERE id = $6 RETURNING *`,
      [name, volume_liters, price_ksh, description, is_active, id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'NOT_FOUND', message: 'Product not found' });
    }
    return res.status(200).json({ product: result.rows[0] });
  } catch (error) {
    console.error('Update product error:', error.message);
    return res.status(500).json({ error: 'SERVER_ERROR', message: 'Something went wrong.' });
  }
};

module.exports = { getProducts, createProduct, updateProduct };
