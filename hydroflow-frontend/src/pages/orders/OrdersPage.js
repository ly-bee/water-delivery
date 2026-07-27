import { useState, useEffect, useCallback, useMemo } from 'react';
import { toast } from 'react-toastify';
import { ShoppingCart, Motorbike, Droplets, Phone, MapPin, UserCheck, Star, RefreshCw } from 'lucide-react';
import DashboardLayout from '../../components/layout/DashboardLayout';
import { orderAPI, driverAPI } from '../../services/api';
import { useAuth } from '../../context/AuthContext';

const STATUS_META = {
  PENDING:    { label: 'Pending',    cls: 'badge-pending'   },
  PAID:       { label: 'Paid',       cls: 'badge-completed' },
  ASSIGNED:   { label: 'Assigned',   cls: 'badge-assigned'  },
  IN_TRANSIT: { label: 'In Transit', cls: 'badge-transit'   },
  DELIVERED:  { label: 'Delivered',  cls: 'badge-delivered' },
  COMPLETED:  { label: 'Completed',  cls: 'badge-completed' },
  CANCELLED:  { label: 'Cancelled',  cls: 'badge-cancelled' },
};

const FILTERS_ADMIN  = ['ALL','PENDING','PAID','ASSIGNED','IN_TRANSIT','DELIVERED','COMPLETED','CANCELLED'];
const FILTERS_DRIVER = ['ALL','ASSIGNED','IN_TRANSIT','DELIVERED'];

/* ─── Admin order card ─────────────────────────────────────────────────────── */
const AdminOrderCard = ({ order, drivers, onRefresh }) => {
  const [loading,   setLoading]   = useState(false);
  const [showAssign,setShowAssign]= useState(false);
  const [driverId,  setDriverId]  = useState('');
  const meta = STATUS_META[order.status] || { label: order.status, cls: 'badge-cancelled' };

  const run = async (fn, msg) => {
    setLoading(true);
    try { await fn(); toast.success(msg); onRefresh(); }
    catch (e) { toast.error(e.response?.data?.message || 'Action failed'); }
    finally { setLoading(false); }
  };

  return (
    <div className="order-card fade-in">
      <div className="order-card-header">
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <div className="avatar">{(order.customer_name || 'C')[0].toUpperCase()}</div>
          <div>
            <p style={{ fontSize: 14, fontWeight: 700, color: 'var(--text-primary)', margin: 0 }}>
              {order.customer_name || 'Customer'}
            </p>
            <p style={{ fontSize: 11, color: 'var(--text-secondary)', margin: '2px 0 0' }}>
              #{order.id.slice(0, 12)} · {new Date(order.created_at).toLocaleDateString('en-KE', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })}
            </p>
          </div>
        </div>
        <span className={`badge ${meta.cls}`}>{meta.label}</span>
      </div>

      <div className="order-card-body">
        <div className="order-info-grid">
          <div className="order-info-cell">
            <p className="order-info-lbl">Volume</p>
            <p className="order-info-val">{order.volume_liters}L</p>
          </div>
          <div className="order-info-cell">
            <p className="order-info-lbl">Amount</p>
            <p className="order-info-val">KSh {parseFloat(order.amount_ksh).toLocaleString()}</p>
          </div>
          <div className="order-info-cell">
            <p className="order-info-lbl">Driver</p>
            <p className="order-info-val">{order.driver_name || '—'}</p>
          </div>
          <div className="order-info-cell">
            <p className="order-info-lbl">Phone</p>
            <p className="order-info-val">{order.customer_phone}</p>
          </div>
        </div>

        {order.delivery_address && (
          <div className="info-row" style={{ marginBottom: 8 }}>
            <MapPin size={12} /><span>{order.delivery_address}</span>
          </div>
        )}
        {order.rating && (
          <div className="info-row" style={{ marginBottom: 8 }}>
            {[1,2,3,4,5].map(s => (
              <Star key={s} size={12} fill={s <= order.rating ? 'var(--accent-positive)' : 'none'} color="var(--accent-positive)" />
            ))}
            <span>Customer rating</span>
          </div>
        )}
        {order.notes && <p style={{ fontSize: 12, color: 'var(--text-secondary)', marginTop: 4 }}>📝 {order.notes}</p>}

        {(order.pod_photo_url || order.pod_signature_url) && (
          <div style={{ marginTop: 10 }}>
            <p style={{ fontSize: 10, fontWeight: 600, color: 'var(--text-secondary)', textTransform: 'uppercase', letterSpacing: '0.06em', margin: '0 0 6px' }}>
              Proof of delivery
            </p>
            <div style={{ display: 'flex', gap: 8 }}>
              {order.pod_photo_url && (
                <a href={order.pod_photo_url} target="_blank" rel="noreferrer">
                  <img src={order.pod_photo_url} alt="Delivery proof" style={{ width: 72, height: 56, objectFit: 'cover', borderRadius: 8, border: '1px solid var(--border)' }} />
                </a>
              )}
              {order.pod_signature_url && (
                <a href={order.pod_signature_url} target="_blank" rel="noreferrer">
                  <img src={order.pod_signature_url} alt="Customer signature" style={{ width: 72, height: 56, objectFit: 'contain', background: '#fff', borderRadius: 8, border: '1px solid var(--border)' }} />
                </a>
              )}
              {order.pod_empty_collected > 0 && (
                <span style={{ alignSelf: 'center', fontSize: 11, color: 'var(--text-secondary)' }}>
                  {order.pod_empty_collected} empt{order.pod_empty_collected === 1 ? 'y' : 'ies'} collected
                </span>
              )}
            </div>
          </div>
        )}

        {showAssign && (
          <div style={{ background: 'var(--bg-elevated)', border: '1px solid var(--border)', borderRadius: 'var(--r-md)', padding: '12px', marginTop: 12 }}>
            <p style={{ fontSize: 13, fontWeight: 600, color: 'var(--text-primary)', margin: '0 0 8px' }}>Select a driver</p>
            <div style={{ display: 'flex', gap: 8 }}>
              <select value={driverId} onChange={e => setDriverId(e.target.value)} className="styled-select" style={{ flex: 1 }}>
                <option value="">Choose driver…</option>
                {(drivers || []).map(d => (
                  <option key={d.id} value={d.id}>{d.name} — {d.vehicle_plate} {d.is_available ? '✓' : '(busy)'}</option>
                ))}
              </select>
              <button className="btn btn-primary btn-sm" disabled={!driverId || loading}
                onClick={() => run(() => orderAPI.assignDriver(order.id, driverId).then(() => { setShowAssign(false); setDriverId(''); }), 'Driver assigned')}>
                Assign
              </button>
              <button className="btn btn-ghost btn-sm" onClick={() => setShowAssign(false)}>Cancel</button>
            </div>
          </div>
        )}
      </div>

      <div className="order-card-footer">
        {['PENDING', 'PAID'].includes(order.status) && (
          <button className="btn btn-primary btn-sm" disabled={loading} onClick={() => setShowAssign(v => !v)}>
            <UserCheck size={12} /> Assign Driver
          </button>
        )}
        {order.status === 'ASSIGNED' && (
          <button className="btn btn-primary btn-sm" disabled={loading}
            onClick={() => run(() => orderAPI.updateStatus(order.id, 'IN_TRANSIT'), 'Marked In Transit')}>
            <Motorbike size={12} /> In Transit
          </button>
        )}
        {order.status === 'IN_TRANSIT' && (
          <button className="btn btn-success btn-sm" disabled={loading}
            onClick={() => run(() => orderAPI.updateStatus(order.id, 'DELIVERED'), 'Marked Delivered')}>
            <Droplets size={12} /> Delivered
          </button>
        )}
        {['PENDING','ASSIGNED'].includes(order.status) && (
          <button className="btn btn-danger btn-sm" disabled={loading}
            onClick={() => run(() => orderAPI.cancel(order.id), 'Order cancelled')}>
            Cancel
          </button>
        )}
      </div>
    </div>
  );
};

/* ─── Driver order card ────────────────────────────────────────────────────── */
const DriverOrderCard = ({ order, onRefresh }) => {
  const [loading, setLoading] = useState(false);
  const meta = STATUS_META[order.status] || { label: order.status, cls: 'badge-cancelled' };

  const handleStatus = async (s) => {
    setLoading(true);
    try { await orderAPI.updateStatus(order.id, s); toast.success(`Order → ${s}`); onRefresh(); }
    catch (e) { toast.error(e.response?.data?.message || 'Update failed'); }
    finally { setLoading(false); }
  };

  const mapsHref = order.delivery_lat
    ? `https://www.google.com/maps?q=${order.delivery_lat},${order.delivery_lng}`
    : `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(order.delivery_address || '')}`;

  return (
    <div className="order-card fade-in">
      <div className="order-card-header">
        <div>
          <p style={{ fontSize: 11, color: 'var(--text-secondary)', margin: '0 0 2px' }}>#{order.id.slice(0, 12)}</p>
          <p style={{ fontSize: 14, fontWeight: 700, color: 'var(--text-primary)', margin: 0 }}>{order.customer_name || 'Customer'}</p>
          <p style={{ fontSize: 11, color: 'var(--text-secondary)', margin: '2px 0 0' }}>
            {new Date(order.created_at).toLocaleDateString('en-KE', { weekday: 'short', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })}
          </p>
        </div>
        <span className={`badge ${meta.cls}`}>{meta.label}</span>
      </div>

      <div className="order-card-body">
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 12 }}>
          <div className="order-info-cell">
            <p className="order-info-lbl">Volume</p>
            <p className="order-info-val" style={{ fontSize: 20 }}>{order.volume_liters}L</p>
          </div>
          <div className="order-info-cell">
            <p className="order-info-lbl">Earnings</p>
            <p className="order-info-val" style={{ fontSize: 20 }}>KSh {parseFloat(order.delivery_fee).toLocaleString()}</p>
          </div>
        </div>

        {/* Customer */}
        <div style={{ border: '1px solid var(--border)', borderRadius: 'var(--r-md)', padding: 12, marginBottom: 8 }}>
          <p style={{ fontSize: 10, fontWeight: 600, color: 'var(--text-secondary)', textTransform: 'uppercase', letterSpacing: '0.06em', margin: '0 0 8px' }}>Customer</p>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <p style={{ fontSize: 14, fontWeight: 600, color: 'var(--text-primary)', margin: 0 }}>{order.customer_name}</p>
              <p style={{ fontSize: 12, color: 'var(--text-secondary)', margin: '2px 0 0' }}>{order.customer_phone}</p>
            </div>
            {order.customer_phone && (
              <a href={`tel:${order.customer_phone}`} className="btn btn-ghost btn-sm">
                <Phone size={12} /> Call
              </a>
            )}
          </div>
        </div>

        {/* Address */}
        <div style={{ border: '1px solid var(--border)', borderRadius: 'var(--r-md)', padding: 12 }}>
          <p style={{ fontSize: 10, fontWeight: 600, color: 'var(--text-secondary)', textTransform: 'uppercase', letterSpacing: '0.06em', margin: '0 0 6px' }}>Delivery Location</p>
          <p style={{ fontSize: 13, color: 'var(--text-primary)', margin: '0 0 8px' }}>{order.delivery_address}</p>
          <a href={mapsHref} target="_blank" rel="noreferrer" className="info-row" style={{ textDecoration: 'none', fontWeight: 600 }}>
            <MapPin size={12} /> Open in Google Maps
          </a>
          {order.notes && <p style={{ fontSize: 12, color: 'var(--text-secondary)', marginTop: 8 }}>📝 {order.notes}</p>}
        </div>
      </div>

      <div className="order-card-footer">
        {order.status === 'ASSIGNED' && (
          <button className="btn btn-primary" style={{ flex: 1 }} disabled={loading} onClick={() => handleStatus('IN_TRANSIT')}>
            <Motorbike size={13} /> Start Delivery
          </button>
        )}
        {order.status === 'IN_TRANSIT' && (
          <button className="btn btn-success" style={{ flex: 1 }} disabled={loading} onClick={() => handleStatus('DELIVERED')}>
            <Droplets size={13} /> Mark Delivered
          </button>
        )}
      </div>
    </div>
  );
};

/* ─── Orders Page ──────────────────────────────────────────────────────────── */
const OrdersPage = () => {
  const [orders,  setOrders]  = useState([]);
  const [drivers, setDrivers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filter,  setFilter]  = useState('ALL');
  const { isDriver, isAdmin } = useAuth();

  const fetchOrders = useCallback(async () => {
    setLoading(true);
    try {
      const [ordersRes, driversRes] = await Promise.all([
        isDriver ? orderAPI.getDriverOrders() : orderAPI.getAllAdmin(),
        isAdmin  ? driverAPI.getAllAdmin()     : Promise.resolve(null),
      ]);
      setOrders(ordersRes.data.orders || []);
      if (driversRes) setDrivers(driversRes.data.drivers || []);
    } catch { toast.error('Failed to load orders'); }
    finally { setLoading(false); }
  }, [isDriver, isAdmin]);

  useEffect(() => { fetchOrders(); }, [fetchOrders]);

  const filtered  = useMemo(() => filter === 'ALL' ? orders : orders.filter(o => o.status === filter), [filter, orders]);
  const filters   = isDriver ? FILTERS_DRIVER : FILTERS_ADMIN;

  /* Driver quick stats */
  const assigned  = useMemo(() => orders.filter(o => o.status === 'ASSIGNED').length, [orders]);
  const inTransit = useMemo(() => orders.filter(o => o.status === 'IN_TRANSIT').length, [orders]);
  const delivered = useMemo(() => orders.filter(o => ['DELIVERED','COMPLETED'].includes(o.status)).length, [orders]);
  const earnings  = useMemo(() => orders.filter(o => ['DELIVERED','COMPLETED'].includes(o.status)).reduce((s,o) => s + (parseFloat(o.delivery_fee)||0), 0), [orders]);

  return (
    <DashboardLayout>
      <div className="page-header">
        <div>
          <h1 className="page-title">{isDriver ? 'My Deliveries' : 'Orders'}</h1>
          <p className="page-subtitle">{orders.length} {isDriver ? 'assigned to you' : 'total orders'}</p>
        </div>
        <button className="btn btn-ghost" onClick={fetchOrders} disabled={loading}>
          <RefreshCw size={13} style={{ animation: loading ? 'spin 0.65s linear infinite' : 'none' }} />
          Refresh
        </button>
      </div>

      {/* Driver stats row */}
      {isDriver && (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4,1fr)', gap: 'var(--grid-gap)', marginBottom: 'var(--grid-gap)' }}>
          {[
            { label: 'Assigned',    value: assigned   },
            { label: 'In Transit',  value: inTransit  },
            { label: 'Delivered',   value: delivered  },
            { label: 'Earnings',    value: `KSh ${earnings.toLocaleString()}` },
          ].map(s => (
            <div key={s.label} className="stat-card">
              <p className="stat-label">{s.label}</p>
              <p className="stat-value" style={{ fontSize: 24 }}>{s.value}</p>
            </div>
          ))}
        </div>
      )}

      {/* Filter pills */}
      <div className="filter-bar">
        {filters.map(f => (
          <button key={f} className={`filter-pill${filter===f?' active':''}`} onClick={() => setFilter(f)}>
            {f === 'ALL' ? 'All' : STATUS_META[f]?.label || f}
            {f !== 'ALL' && <span style={{ marginLeft: 4, opacity: 0.65 }}>{orders.filter(o=>o.status===f).length}</span>}
          </button>
        ))}
      </div>

      {loading ? (
        <div className="loading-center"><div className="spinner" /><span>Loading orders…</span></div>
      ) : filtered.length === 0 ? (
        <div className="card">
          <div className="empty-state">
            <ShoppingCart size={26} className="empty-icon" />
            <p className="empty-title">{filter==='ALL' ? 'No orders yet' : `No ${STATUS_META[filter]?.label||filter} orders`}</p>
            <p className="empty-sub">Orders will appear here as they come in.</p>
          </div>
        </div>
      ) : filtered.map(o =>
        isDriver
          ? <DriverOrderCard key={o.id} order={o} onRefresh={fetchOrders} />
          : <AdminOrderCard  key={o.id} order={o} onRefresh={fetchOrders} drivers={drivers} />
      )}
    </DashboardLayout>
  );
};

export default OrdersPage;
