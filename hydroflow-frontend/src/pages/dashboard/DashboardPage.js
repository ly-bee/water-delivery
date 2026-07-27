import { useState, useEffect, useCallback, useMemo } from 'react';
import { toast } from 'react-toastify';
import { ShoppingCart, RefreshCw } from 'lucide-react';
import DashboardLayout from '../../components/layout/DashboardLayout';
import { useAuth } from '../../context/AuthContext';
import { orderAPI, userAPI, driverAPI } from '../../services/api';

/* ─── Status display ───────────────────────────────────────────────────────── */
const STATUS_META = {
  PENDING:    { label: 'Pending',    cls: 'badge-pending'   },
  PAID:       { label: 'Paid',       cls: 'badge-completed' },
  ASSIGNED:   { label: 'Assigned',   cls: 'badge-assigned'  },
  IN_TRANSIT: { label: 'In Transit', cls: 'badge-transit'   },
  DELIVERED:  { label: 'Delivered',  cls: 'badge-delivered' },
  COMPLETED:  { label: 'Completed',  cls: 'badge-completed' },
  CANCELLED:  { label: 'Cancelled',  cls: 'badge-cancelled' },
};

function getGreeting() {
  const h = new Date().getHours();
  return h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening';
}

function initials(name = '') {
  const p = (name || '').trim().split(' ');
  return p.length >= 2 ? (p[0][0] + p[1][0]).toUpperCase() : (name[0] || '?').toUpperCase();
}

/* ─── SVG Bar Chart — orders per day, last 7 days ─────────────────────────── */
function buildDayBuckets(orders) {
  const today = new Date();
  return Array.from({ length: 7 }, (_, i) => {
    const d = new Date(today);
    d.setDate(d.getDate() - (6 - i));
    const key = d.toISOString().slice(0, 10);
    return {
      date: d,
      label: d.toLocaleDateString('en', { weekday: 'short' }).slice(0, 3),
      count: orders.filter(o => (o.created_at || '').slice(0, 10) === key).length,
      isToday: d.toDateString() === today.toDateString(),
    };
  });
}

const OrdersChart = ({ orders }) => {
  const data  = useMemo(() => buildDayBuckets(orders), [orders]);
  const max   = Math.max(...data.map(d => d.count), 1);
  const BAR_W = 32;
  const BAR_G = 12;
  const H     = 100;
  const W     = data.length * (BAR_W + BAR_G) - BAR_G;

  return (
    <svg
      viewBox={`0 0 ${W} ${H + 24}`}
      style={{ width: '100%', overflow: 'visible', display: 'block' }}
      preserveAspectRatio="none"
    >
      {data.map(({ label, count, isToday }, i) => {
        const x  = i * (BAR_W + BAR_G);
        const bh = count > 0 ? Math.max((count / max) * H, 6) : 0;
        return (
          <g key={i}>
            {/* Background track */}
            <rect x={x} y={0} width={BAR_W} height={H}
              fill="var(--bg-page)" rx={4} />
            {/* Value bar */}
            {count > 0 && (
              <rect x={x} y={H - bh} width={BAR_W} height={bh}
                fill={isToday ? 'var(--bg-primary)' : 'var(--bg-muted)'} rx={4} />
            )}
            {/* Count label on filled bar */}
            {count > 0 && (
              <text x={x + BAR_W / 2} y={H - bh - 5}
                textAnchor="middle" fontSize={10} fontWeight={600}
                fill={isToday ? 'var(--text-primary)' : 'var(--text-secondary)'}
              >{count}</text>
            )}
            {/* Day label */}
            <text x={x + BAR_W / 2} y={H + 16}
              textAnchor="middle" fontSize={11}
              fontWeight={isToday ? 600 : 400}
              fill={isToday ? 'var(--text-primary)' : 'var(--text-secondary)'}
            >{label}</text>
          </g>
        );
      })}
    </svg>
  );
};

/* ─── Mini Calendar ────────────────────────────────────────────────────────── */
const MiniCalendar = ({ orders }) => {
  const today = new Date();
  const yr    = today.getFullYear();
  const mo    = today.getMonth();

  const firstDow  = new Date(yr, mo, 1).getDay();
  const daysInMo  = new Date(yr, mo + 1, 0).getDate();
  const monthName = today.toLocaleDateString('en', { month: 'long', year: 'numeric' });

  const orderDays = new Set(
    orders
      .map(o => { const d = new Date(o.created_at); return d.getFullYear() === yr && d.getMonth() === mo ? d.getDate() : null; })
      .filter(Boolean)
  );

  const cells = [...Array(firstDow).fill(null), ...Array.from({ length: daysInMo }, (_, i) => i + 1)];
  const DOW   = ['S','M','T','W','T','F','S'];

  return (
    <>
      <p style={{ fontSize: 13, fontWeight: 600, color: 'var(--text-primary)', marginBottom: 4 }}>{monthName}</p>
      <p style={{ fontSize: 11, color: 'var(--text-secondary)' }}>
        {orderDays.size} order day{orderDays.size !== 1 ? 's' : ''} this month
      </p>
      <div className="cal-grid" style={{ marginTop: 16 }}>
        {DOW.map((d, i) => <div key={i} className="cal-dow">{d}</div>)}
        {cells.map((d, i) => (
          <div
            key={i}
            className={[
              'cal-day',
              !d               ? 'empty'     : '',
              d === today.getDate() ? 'today' : '',
              d && orderDays.has(d) ? 'has-order' : '',
            ].join(' ')}
          >
            {d || ''}
          </div>
        ))}
      </div>
    </>
  );
};

/* ─── Dashboard Page ───────────────────────────────────────────────────────── */
const DashboardPage = () => {
  const { user } = useAuth();

  const [stats,        setStats]        = useState(null);
  const [allOrders,    setAllOrders]    = useState([]);
  const [recentOrders, setRecentOrders] = useState([]);
  const [userCount,    setUserCount]    = useState(0);
  const [driverCount,  setDriverCount]  = useState(0);
  const [loading,      setLoading]      = useState(true);
  const [refreshing,   setRefreshing]   = useState(false);

  const load = useCallback(async (isRefresh = false) => {
    if (isRefresh) setRefreshing(true); else setLoading(true);
    try {
      const [oRes, uRes, dRes] = await Promise.all([
        orderAPI.getAllAdmin(),
        userAPI.getAll(),
        driverAPI.getAllAdmin(),
      ]);
      const orders = oRes.data.orders || [];
      setStats(oRes.data.stats);
      setAllOrders(orders);
      setRecentOrders(orders.slice(0, 8));
      setUserCount(uRes.data.count || 0);
      setDriverCount(dRes.data.count || 0);
    } catch { toast.error('Failed to load dashboard'); }
    finally { setLoading(false); setRefreshing(false); }
  }, []);

  useEffect(() => { load(); }, [load]);

  const revenue = useMemo(() => (stats?.totalRevenue || 0).toLocaleString(), [stats]);
  const today   = useMemo(() => new Date().toLocaleDateString('en', { weekday: 'long', month: 'long', day: 'numeric' }), []);

  if (loading) {
    return (
      <DashboardLayout>
        <div className="loading-center"><div className="spinner" /><span>Loading dashboard…</span></div>
      </DashboardLayout>
    );
  }

  const COL = 'gridTemplateColumns';

  return (
    <DashboardLayout>

      {/* ── Header ── */}
      <div className="page-header">
        <div>
          <h1 className="page-title">{getGreeting()}, {user?.name?.split(' ')[0]}</h1>
          <p className="page-subtitle">{today}</p>
        </div>
        <button className="btn btn-ghost" onClick={() => load(true)} disabled={refreshing}>
          <RefreshCw size={13} style={{ animation: refreshing ? 'spin 0.65s linear infinite' : 'none' }} />
          Refresh
        </button>
      </div>

      {/* ════════════════════════════════════════════════════════════════════
          ROW 1 — Hero (4 cols) + 3 secondary stats (2.67 cols each)
          ════════════════════════════════════════════════════════════════════ */}
      <div className="dash-row-stats">

        {/* Hero card — dark bg, diagonal texture */}
        <div className="hero-card">
          <p className="stat-label">Total Revenue</p>
          <div>
            <p className="stat-value">KSh {revenue}</p>
            <p className="stat-sub" style={{ marginTop: 8 }}>
              {stats?.completed || 0} completed · {stats?.pending || 0} pending
            </p>
          </div>
        </div>

        {/* Secondary — Total Orders */}
        <div className="stat-card">
          <p className="stat-label">Total Orders</p>
          <p className="stat-value">{stats?.total || 0}</p>
          <p className="stat-sub">{stats?.active || 0} active</p>
        </div>

        {/* Secondary — Users */}
        <div className="stat-card">
          <p className="stat-label">Registered Users</p>
          <p className="stat-value">{userCount}</p>
          <p className="stat-sub">Total clients</p>
        </div>

        {/* Secondary — Drivers */}
        <div className="stat-card">
          <p className="stat-label">Active Drivers</p>
          <p className="stat-value">{driverCount}</p>
          <p className="stat-sub">Registered drivers</p>
        </div>
      </div>

      {/* ════════════════════════════════════════════════════════════════════
          ROW 2 — Chart (8 cols) + Calendar widget (4 cols)
          ════════════════════════════════════════════════════════════════════ */}
      <div className="dash-row-chart">

        {/* Chart card */}
        <div className="card">
          <div className="panel-head" style={{ padding: '16px 24px' }}>
            <div>
              <p className="panel-title">Orders — last 7 days</p>
              <p style={{ fontSize: 12, color: 'var(--text-secondary)', marginTop: 2 }}>
                {allOrders.length} total orders on record
              </p>
            </div>
            <span style={{ fontSize: 11, color: 'var(--text-secondary)', textTransform: 'uppercase', letterSpacing: '0.07em', fontWeight: 600 }}>
              Daily volume
            </span>
          </div>
          <div style={{ padding: '24px 24px 20px' }}>
            <OrdersChart orders={allOrders} />
          </div>
        </div>

        {/* Calendar widget */}
        <div className="card card-pad">
          <MiniCalendar orders={allOrders} />
        </div>
      </div>

      {/* ════════════════════════════════════════════════════════════════════
          ROW 3 — Recent orders table (full 12 cols)
          Dense rows, no zebra, left-aligned numerics, tabular-nums
          ════════════════════════════════════════════════════════════════════ */}
      <div className="card fade-in">
        <div className="panel-head">
          <p className="panel-title">Recent Orders</p>
          <span style={{ fontSize: 12, color: 'var(--text-secondary)' }}>Last {recentOrders.length}</span>
        </div>

        {recentOrders.length === 0 ? (
          <div className="empty-state">
            <ShoppingCart size={28} className="empty-icon" />
            <p className="empty-title">No orders yet</p>
            <p className="empty-sub">Orders will appear here once customers start placing them.</p>
          </div>
        ) : (
          <>
            <div className="table-head-row" style={{ [COL]: '28px 2fr 2fr 1.2fr 72px 130px 112px' }}>
              <span>#</span><span>Customer</span><span>Address</span>
              <span>Amount</span><span>Vol.</span><span>Placed</span><span>Status</span>
            </div>
            {recentOrders.map((o, i) => {
              const m = STATUS_META[o.status] || { label: o.status, cls: 'badge-cancelled' };
              return (
                <div key={o.id} className="table-data-row" style={{ [COL]: '28px 2fr 2fr 1.2fr 72px 130px 112px' }}>
                  <span style={{ fontSize: 12, color: 'var(--text-secondary)' }}>{i + 1}</span>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                    <div className="avatar">{initials(o.customer_name)}</div>
                    <div>
                      <p style={{ fontSize: 13, fontWeight: 600, margin: 0 }}>{o.customer_name || 'Customer'}</p>
                      <p style={{ fontSize: 11, color: 'var(--text-secondary)', margin: '1px 0 0' }}>{o.customer_phone}</p>
                    </div>
                  </div>
                  <p style={{ fontSize: 12, color: 'var(--text-secondary)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', margin: 0 }}>
                    {o.delivery_address}
                  </p>
                  <p className="num" style={{ fontSize: 13, fontWeight: 600, margin: 0 }}>
                    KSh {parseFloat(o.amount_ksh).toLocaleString()}
                  </p>
                  <p className="num" style={{ fontSize: 13, color: 'var(--text-secondary)', margin: 0 }}>
                    {o.volume_liters}L
                  </p>
                  <p style={{ fontSize: 12, color: 'var(--text-secondary)', margin: 0 }}>
                    {new Date(o.created_at).toLocaleDateString('en-KE', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })}
                  </p>
                  <span className={`badge ${m.cls}`}>{m.label}</span>
                </div>
              );
            })}
          </>
        )}
      </div>
    </DashboardLayout>
  );
};

export default DashboardPage;
