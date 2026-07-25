const { pool } = require('../config/db');

// GET /api/admin/stats
const getStats = async (req, res) => {
  try {
    const [orderStats, driverStats, revenueByDay] = await Promise.all([
      pool.query(`
        SELECT
          COUNT(*)::INT                                                  AS total_orders,
          COUNT(*) FILTER (WHERE status = 'PENDING')::INT               AS pending,
          COUNT(*) FILTER (WHERE status IN ('ASSIGNED','IN_TRANSIT'))::INT AS active,
          COUNT(*) FILTER (WHERE status IN ('DELIVERED','COMPLETED'))::INT AS delivered,
          COUNT(*) FILTER (WHERE status = 'CANCELLED')::INT             AS cancelled,
          COUNT(*) FILTER (WHERE DATE(created_at) = CURRENT_DATE)::INT  AS today_orders,
          COALESCE(SUM(amount_ksh) FILTER (
            WHERE status IN ('DELIVERED','COMPLETED')
          ), 0)::FLOAT                                                   AS total_revenue,
          COALESCE(SUM(amount_ksh) FILTER (
            WHERE status IN ('DELIVERED','COMPLETED')
              AND DATE(completed_at) = CURRENT_DATE
          ), 0)::FLOAT                                                   AS today_revenue
        FROM orders
      `),
      pool.query(`
        SELECT
          COUNT(*)::INT                                          AS total_drivers,
          COUNT(*) FILTER (WHERE status = 'available')::INT     AS online,
          COUNT(*) FILTER (WHERE status = 'on_delivery')::INT   AS on_delivery,
          COUNT(*) FILTER (WHERE status = 'offline')::INT       AS offline,
          COUNT(*) FILTER (WHERE is_verified = true)::INT       AS verified
        FROM drivers
      `),
      pool.query(`
        SELECT
          DATE(completed_at)::TEXT AS day,
          SUM(amount_ksh)::FLOAT   AS revenue,
          COUNT(*)::INT            AS deliveries
        FROM orders
        WHERE status IN ('DELIVERED','COMPLETED')
          AND completed_at >= NOW() - INTERVAL '30 days'
        GROUP BY DATE(completed_at)
        ORDER BY day ASC
      `),
    ]);

    return res.status(200).json({
      orders:      orderStats.rows[0],
      drivers:     driverStats.rows[0],
      revenue_by_day: revenueByDay.rows,
    });
  } catch (err) {
    console.error('getStats error:', err.message);
    return res.status(500).json({ error: 'SERVER_ERROR', message: 'Something went wrong.' });
  }
};

module.exports = { getStats };
