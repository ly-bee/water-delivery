import { useState, useEffect, useCallback, useRef, useMemo } from 'react';
import { MapContainer, TileLayer, Marker, Popup, useMap } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import io from 'socket.io-client';
import { toast } from 'react-toastify';
import {
  RefreshCw, Search, X, Star, Shield, ShieldOff, ChevronRight,
  MapPin, Navigation, Wifi, WifiOff, AlertCircle, Package, Clock,
} from 'lucide-react';
import DashboardLayout from '../../components/layout/DashboardLayout';
import { driverAPI } from '../../services/api';

/* ─── leaflet icon fix ───────────────────────────────────────────────────── */
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png',
  iconUrl:       'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png',
  shadowUrl:     'https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png',
});

/* ─── constants ──────────────────────────────────────────────────────────── */
const CENTER = [-1.0996, 37.0144];

const SOCKET_URL = (process.env.REACT_APP_API_URL || 'http://localhost:3000/api').replace('/api', '');

const STATUS_CFG = {
  available:   { label: 'Available',   color: '#5e8f67', bg: 'rgba(94,143,112,0.1)',  border: 'rgba(94,143,112,0.22)'  },
  on_delivery: { label: 'On Delivery', color: '#D4923B', bg: 'rgba(212,146,59,0.1)',  border: 'rgba(212,146,59,0.22)'  },
  offline:     { label: 'Offline',     color: '#8A888B', bg: 'rgba(138,136,139,0.1)', border: 'rgba(138,136,139,0.22)' },
  suspended:   { label: 'Suspended',   color: '#A85C49', bg: 'rgba(168,92,73,0.1)',   border: 'rgba(168,92,73,0.22)'   },
};

const FILTERS = ['all', 'available', 'on_delivery', 'offline', 'suspended'];

const MARKER_COLOR = {
  available:   '#5E8F70',
  on_delivery: '#D4923B',
  offline:     '#8A888B',
  suspended:   '#A85C49',
};

/* ─── helpers ────────────────────────────────────────────────────────────── */
const initials = (name = '') => {
  const p = (name || '').trim().split(' ');
  return p.length >= 2 ? (p[0][0] + p[1][0]).toUpperCase() : (name[0] || '?').toUpperCase();
};

const effectiveStatus = (d) => d.status || (d.is_available ? 'available' : 'offline');

const createMarkerIcon = (status, isSelected) => L.divIcon({
  className: '',
  html: `<div style="
    width:${isSelected ? 40 : 34}px;height:${isSelected ? 40 : 34}px;
    background:${MARKER_COLOR[status] || '#8A888B'};
    border:${isSelected ? '3px solid #1E1E1E' : '2.5px solid white'};
    border-radius:50%;display:flex;align-items:center;justify-content:center;
    box-shadow:${isSelected ? '0 0 0 3px rgba(94,143,112,0.3),0 4px 12px rgba(0,0,0,0.3)' : '0 2px 6px rgba(0,0,0,0.2)'};
    font-size:${isSelected ? 16 : 13}px;">🏍️</div>`,
  iconSize:    [isSelected ? 40 : 34, isSelected ? 40 : 34],
  iconAnchor:  [isSelected ? 20 : 17, isSelected ? 20 : 17],
  popupAnchor: [0, -22],
});

/* ─── MapFlyTo ───────────────────────────────────────────────────────────── */
const MapFlyTo = ({ position }) => {
  const map = useMap();
  useEffect(() => {
    if (position) map.flyTo(position, 15, { duration: 1.1 });
  }, [position, map]);
  return null;
};

/* ─── StatusBadge ────────────────────────────────────────────────────────── */
const StatusBadge = ({ status }) => {
  const cfg = STATUS_CFG[status] || STATUS_CFG.offline;
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 5,
      padding: '3px 9px', borderRadius: 'var(--r-pill)',
      background: cfg.bg, border: `1px solid ${cfg.border}`,
      fontSize: 11, fontWeight: 600, color: cfg.color,
      whiteSpace: 'nowrap',
    }}>
      <div style={{ width: 5, height: 5, borderRadius: '50%', background: cfg.color }} />
      {cfg.label}
    </span>
  );
};

/* ─── DriverRow ──────────────────────────────────────────────────────────── */
const DriverRow = ({ driver, isSelected, onSelect }) => {
  const status    = effectiveStatus(driver);
  const rating    = parseFloat(driver.avg_rating) || 0;
  const todayDone = parseInt(driver.today_deliveries) || 0;

  return (
    <div
      className="table-data-row"
      style={{
        gridTemplateColumns: '2.4fr 1.5fr 1.1fr 0.65fr 0.65fr 28px',
        cursor: 'pointer',
        background: isSelected ? 'var(--bg-elevated)' : undefined,
      }}
      onClick={() => onSelect(driver)}
    >
      {/* Name */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
        <div className="avatar">{initials(driver.name)}</div>
        <div>
          <p style={{ fontSize: 13, fontWeight: 600, color: 'var(--text-primary)', margin: 0 }}>{driver.name}</p>
          <p style={{ fontSize: 11, color: 'var(--text-secondary)', margin: '1px 0 0' }}>{driver.phone}</p>
        </div>
      </div>

      {/* Status + active order context */}
      <div>
        <StatusBadge status={status} />
        {status === 'on_delivery' && driver.active_order_id && (
          <p style={{ fontSize: 10, color: 'var(--text-secondary)', margin: '3px 0 0', fontFamily: 'monospace' }}>
            #{driver.active_order_id.slice(0, 8).toUpperCase()}
          </p>
        )}
      </div>

      {/* Plate */}
      <span style={{
        fontSize: 11, fontWeight: 700, letterSpacing: '0.05em',
        color: 'var(--text-primary)', fontFamily: 'monospace',
        background: 'var(--bg-elevated)', border: '1px solid var(--border)',
        padding: '2px 7px', borderRadius: 4,
      }}>
        {driver.vehicle_plate || '—'}
      </span>

      {/* Today */}
      <span className="num" style={{ fontSize: 13, fontWeight: 600, color: 'var(--text-primary)' }}>
        {todayDone}
      </span>

      {/* Rating */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 3 }}>
        <Star size={11} style={{ color: rating > 0 ? '#D4923B' : 'var(--text-secondary)' }} />
        <span style={{ fontSize: 12, fontWeight: 600, color: rating > 0 ? 'var(--text-primary)' : 'var(--text-secondary)' }}>
          {rating > 0 ? rating.toFixed(1) : '—'}
        </span>
      </div>

      <ChevronRight size={14} style={{ color: 'var(--text-secondary)' }} />
    </div>
  );
};

/* ─── LiveMap ────────────────────────────────────────────────────────────── */
const LiveMap = ({ drivers, selectedId, onSelectDriver, filter }) => {
  const [positions,  setPositions]  = useState({});
  const [connected,  setConnected]  = useState(false);
  const [flyTo,      setFlyTo]      = useState(null);
  const prevSelectedRef = useRef(null);

  /* socket connection */
  useEffect(() => {
    const token = localStorage.getItem('hydroflow_token');
    if (!token) return;

    const socket = io(SOCKET_URL, {
      auth: { token },
      transports: ['websocket', 'polling'],
      reconnectionDelay: 2000,
    });

    socket.on('connect',       () => setConnected(true));
    socket.on('disconnect',    () => setConnected(false));
    socket.on('connect_error', () => setConnected(false));

    socket.on('driver:location', ({ driverId, lat, lng, status, updatedAt }) => {
      setPositions(prev => ({ ...prev, [driverId]: { lat, lng, status, updatedAt } }));
    });

    socket.on('driver:status', ({ driverId, status }) => {
      setPositions(prev =>
        prev[driverId] ? { ...prev, [driverId]: { ...prev[driverId], status } } : prev
      );
    });

    return () => socket.disconnect();
  }, []);

  /* polling fallback when socket is disconnected */
  useEffect(() => {
    if (connected) return;
    const poll = async () => {
      try {
        const r = await driverAPI.getLocations();
        const loc = {};
        (r.data.locations || []).forEach(d => {
          if (d.current_lat) {
            loc[d.id] = {
              lat: parseFloat(d.current_lat),
              lng: parseFloat(d.current_lng),
              status: d.status,
            };
          }
        });
        setPositions(loc);
      } catch {}
    };
    const iv = setInterval(poll, 30000);
    return () => clearInterval(iv);
  }, [connected]);

  /* fly to newly selected driver */
  useEffect(() => {
    if (!selectedId || selectedId === prevSelectedRef.current) return;
    prevSelectedRef.current = selectedId;
    const d = drivers.find(dr => dr.id === selectedId);
    const p = positions[selectedId];
    const lat = p?.lat ?? (d?.current_lat ? parseFloat(d.current_lat) : null);
    const lng = p?.lng ?? (d?.current_lng ? parseFloat(d.current_lng) : null);
    if (lat && lng) setFlyTo([lat, lng]);
  }, [selectedId, drivers, positions]);

  /* merge socket positions into driver list */
  const merged = drivers.map(d => {
    const p = positions[d.id];
    return {
      ...d,
      current_lat: p?.lat ?? (d.current_lat ? parseFloat(d.current_lat) : null),
      current_lng: p?.lng ?? (d.current_lng ? parseFloat(d.current_lng) : null),
      status: p?.status || effectiveStatus(d),
    };
  });

  const visible = (filter === 'all' ? merged : merged.filter(d => d.status === filter))
    .filter(d => d.current_lat && d.current_lng);

  return (
    <div style={{
      background: 'var(--bg-surface)',
      borderRadius: 'var(--r-lg)',
      border: '1px solid var(--border)',
      overflow: 'hidden',
      position: 'sticky',
      top: 32,
    }}>
      {/* connection banner */}
      {!connected && (
        <div style={{
          padding: '7px 16px',
          background: 'rgba(168,92,73,0.08)',
          borderBottom: '1px solid var(--border)',
          display: 'flex', alignItems: 'center', gap: 7,
          fontSize: 11, color: 'var(--accent-negative)',
        }}>
          <WifiOff size={12} /> Live updates paused — reconnecting…
        </div>
      )}

      {/* header */}
      <div className="panel-head">
        <p className="panel-title">Fleet Map</p>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
          <div style={{ width: 7, height: 7, borderRadius: '50%', background: connected ? 'var(--accent-positive)' : '#8A888B' }} />
          <span style={{ fontSize: 11, color: 'var(--text-secondary)' }}>{connected ? 'Live' : 'Polling'}</span>
          <span style={{ fontSize: 11, color: 'var(--text-secondary)', marginLeft: 4 }}>· {visible.length} shown</span>
        </div>
      </div>

      {/* map */}
      <div style={{ height: 420 }}>
        <MapContainer center={CENTER} zoom={13} style={{ height: '100%', width: '100%' }}>
          <MapFlyTo position={flyTo} />
          <TileLayer
            attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
            url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
          />
          {visible.map(d => (
            <Marker
              key={d.id}
              position={[d.current_lat, d.current_lng]}
              icon={createMarkerIcon(d.status, d.id === selectedId)}
              eventHandlers={{ click: () => onSelectDriver(d) }}
            >
              <Popup>
                <div style={{ minWidth: 140 }}>
                  <p style={{ fontWeight: 700, margin: '0 0 2px', fontSize: 13 }}>{d.name}</p>
                  <p style={{ margin: '0 0 6px', fontSize: 11, color: '#64748B' }}>{d.phone} · {d.vehicle_plate}</p>
                  <span style={{
                    padding: '2px 8px', borderRadius: 4, fontSize: 11, fontWeight: 700,
                    background: STATUS_CFG[d.status]?.bg || STATUS_CFG.offline.bg,
                    color: STATUS_CFG[d.status]?.color || STATUS_CFG.offline.color,
                  }}>
                    {STATUS_CFG[d.status]?.label || 'Unknown'}
                  </span>
                </div>
              </Popup>
            </Marker>
          ))}
        </MapContainer>
      </div>

      {/* legend */}
      <div style={{
        padding: '10px 16px', borderTop: '1px solid var(--border)',
        background: 'var(--bg-elevated)',
        display: 'flex', gap: 14, flexWrap: 'wrap',
      }}>
        {Object.entries(STATUS_CFG).map(([k, v]) => (
          <div key={k} style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
            <div style={{ width: 8, height: 8, borderRadius: '50%', background: v.color }} />
            <span style={{ fontSize: 11, color: 'var(--text-secondary)' }}>{v.label}</span>
          </div>
        ))}
      </div>
    </div>
  );
};

/* ─── DriverDrawer ───────────────────────────────────────────────────────── */
const DriverDrawer = ({ driver, detail, loading, onClose, onSuspend, onReassign, allDrivers, suspendLoading, reassignLoading }) => {
  const [tab,             setTab]             = useState('profile');
  const [newDriverId,     setNewDriverId]     = useState('');
  const [reassignExpanded,setReassignExpanded]= useState(false);

  const open = !!driver;
  const status = driver ? effectiveStatus(driver) : 'offline';
  const perf = detail?.performance || {};
  const availableForReassign = allDrivers.filter(d => effectiveStatus(d) === 'available' && d.id !== driver?.id);

  return (
    <>
      {/* backdrop */}
      {open && (
        <div
          style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.15)', zIndex: 999 }}
          onClick={onClose}
        />
      )}

      {/* drawer */}
      <div style={{
        position: 'fixed', top: 0,
        right: open ? 0 : -490,
        width: 460, height: '100vh',
        background: 'var(--bg-surface)',
        borderLeft: '1px solid var(--border)',
        zIndex: 1000,
        transition: 'right 0.25s cubic-bezier(0.4,0,0.2,1)',
        display: 'flex', flexDirection: 'column',
        overflow: 'hidden',
      }}>
        {!driver ? null : (
          <>
            {/* drawer header */}
            <div style={{
              padding: '20px 24px 16px',
              borderBottom: '1px solid var(--border)',
              flexShrink: 0,
            }}>
              <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', marginBottom: 12 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                  <div style={{
                    width: 44, height: 44, borderRadius: '50%',
                    background: STATUS_CFG[status]?.bg || 'var(--bg-elevated)',
                    border: `1.5px solid ${STATUS_CFG[status]?.border || 'var(--border)'}`,
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    fontSize: 17, fontWeight: 700, color: STATUS_CFG[status]?.color || 'var(--text-secondary)',
                  }}>
                    {initials(driver.name)}
                  </div>
                  <div>
                    <p style={{ fontSize: 16, fontWeight: 700, color: 'var(--text-primary)', margin: 0 }}>{driver.name}</p>
                    <div style={{ marginTop: 5 }}><StatusBadge status={status} /></div>
                  </div>
                </div>
                <button className="btn btn-ghost btn-xs" onClick={onClose} title="Close">
                  <X size={14} />
                </button>
              </div>

              {/* tabs */}
              <div style={{ display: 'flex', gap: 4 }}>
                {[['profile', 'Profile'], ['performance', 'Performance'], ['history', 'History']].map(([k, label]) => (
                  <button
                    key={k}
                    onClick={() => setTab(k)}
                    style={{
                      padding: '5px 14px', borderRadius: 'var(--r-pill)',
                      border: 'none', cursor: 'pointer', fontSize: 12, fontWeight: 600,
                      background: tab === k ? 'var(--btn-bg)' : 'transparent',
                      color: tab === k ? 'var(--btn-text)' : 'var(--text-secondary)',
                      transition: 'all 0.12s',
                    }}
                  >
                    {label}
                  </button>
                ))}
              </div>
            </div>

            {/* drawer body */}
            <div style={{ flex: 1, overflowY: 'auto', padding: '20px 24px' }}>
              {loading ? (
                <div className="loading-center" style={{ paddingTop: 48 }}><div className="spinner" /></div>
              ) : tab === 'profile' ? (
                <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
                  {/* Info rows */}
                  {[
                    { label: 'Phone',     value: driver.phone },
                    { label: 'Email',     value: detail?.profile?.email || driver.email || '—' },
                    { label: 'Plate',     value: driver.vehicle_plate, mono: true },
                    { label: 'Verified',  value: driver.is_verified ? '✓ Account verified' : '✗ Not verified' },
                    { label: 'Location',  value: driver.current_lat ? `${parseFloat(driver.current_lat).toFixed(4)}, ${parseFloat(driver.current_lng).toFixed(4)}` : 'No data' },
                    { label: 'Last ping', value: driver.location_updated_at ? new Date(driver.location_updated_at).toLocaleString() : 'Never' },
                  ].map(({ label, value, mono }) => (
                    <div key={label} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', paddingBottom: 12, borderBottom: '1px solid var(--border)' }}>
                      <span style={{ fontSize: 12, color: 'var(--text-secondary)' }}>{label}</span>
                      <span style={{
                        fontSize: 13, fontWeight: 600, color: 'var(--text-primary)',
                        fontFamily: mono ? 'monospace' : undefined, letterSpacing: mono ? '0.06em' : undefined,
                      }}>
                        {value}
                      </span>
                    </div>
                  ))}
                </div>
              ) : tab === 'performance' ? (
                <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
                  {/* Completion rate bar */}
                  <div>
                    <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 8 }}>
                      <span style={{ fontSize: 12, color: 'var(--text-secondary)' }}>Completion Rate</span>
                      <span style={{ fontSize: 13, fontWeight: 700, color: 'var(--text-primary)' }}>
                        {perf.completion_rate || 0}%
                      </span>
                    </div>
                    <div style={{ height: 6, background: 'var(--bg-elevated)', borderRadius: 3, overflow: 'hidden' }}>
                      <div style={{
                        height: '100%', borderRadius: 3,
                        width: `${perf.completion_rate || 0}%`,
                        background: parseFloat(perf.completion_rate) >= 80 ? 'var(--accent-positive)' : 'var(--accent-negative)',
                        transition: 'width 0.6s ease',
                      }} />
                    </div>
                  </div>

                  {/* Stat grid */}
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
                    {[
                      { label: 'Total Orders',       value: perf.total_orders     || 0 },
                      { label: 'Completed',           value: perf.completed        || 0 },
                      { label: 'Cancelled',           value: perf.cancelled        || 0 },
                      { label: 'Today\'s Deliveries', value: perf.today_deliveries || 0 },
                    ].map(({ label, value }) => (
                      <div key={label} style={{ padding: '12px 14px', background: 'var(--bg-elevated)', borderRadius: 'var(--r-md)', border: '1px solid var(--border)' }}>
                        <p style={{ fontSize: 22, fontWeight: 700, color: 'var(--text-primary)', margin: '0 0 2px' }}>{value}</p>
                        <p style={{ fontSize: 11, color: 'var(--text-secondary)', margin: 0 }}>{label}</p>
                      </div>
                    ))}
                  </div>

                  {/* Rating */}
                  <div style={{ padding: '14px 16px', background: 'var(--bg-elevated)', borderRadius: 'var(--r-md)', border: '1px solid var(--border)' }}>
                    <p style={{ fontSize: 11, color: 'var(--text-secondary)', margin: '0 0 6px' }}>Average Rating</p>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                      <span style={{ fontSize: 28, fontWeight: 700, color: 'var(--text-primary)' }}>
                        {perf.avg_rating || '—'}
                      </span>
                      <div style={{ display: 'flex', gap: 2 }}>
                        {[1,2,3,4,5].map(i => (
                          <Star key={i} size={14} style={{
                            color: i <= Math.round(parseFloat(perf.avg_rating) || 0) ? '#D4923B' : 'var(--border)',
                            fill: i <= Math.round(parseFloat(perf.avg_rating) || 0) ? '#D4923B' : 'transparent',
                          }} />
                        ))}
                      </div>
                    </div>
                  </div>
                </div>
              ) : (
                /* History tab */
                <div>
                  {(!detail?.history || detail.history.length === 0) ? (
                    <div className="empty-state" style={{ paddingTop: 32 }}>
                      <Package size={24} className="empty-icon" />
                      <p className="empty-title">No delivery history</p>
                    </div>
                  ) : (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                      {detail.history.map(order => (
                        <div key={order.id} style={{
                          padding: '12px 14px', background: 'var(--bg-elevated)',
                          borderRadius: 'var(--r-md)', border: '1px solid var(--border)',
                        }}>
                          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 6 }}>
                            <span style={{ fontSize: 11, fontFamily: 'monospace', color: 'var(--text-secondary)' }}>
                              #{order.id.slice(0, 8).toUpperCase()}
                            </span>
                            <StatusBadge status={order.status?.toLowerCase().replace('_', '_') || 'offline'} />
                          </div>
                          <p style={{ fontSize: 12, color: 'var(--text-secondary)', margin: '0 0 4px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                            {order.delivery_address}
                          </p>
                          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                            <span style={{ fontSize: 12, fontWeight: 600, color: 'var(--text-primary)' }}>
                              KSh {parseFloat(order.amount_ksh).toLocaleString()} · {order.volume_liters}L
                            </span>
                            {order.rating && (
                              <div style={{ display: 'flex', alignItems: 'center', gap: 3 }}>
                                <Star size={11} style={{ color: '#D4923B' }} />
                                <span style={{ fontSize: 12, fontWeight: 600, color: 'var(--text-primary)' }}>{order.rating}</span>
                              </div>
                            )}
                          </div>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              )}
            </div>

            {/* actions footer */}
            <div style={{
              padding: '16px 24px', borderTop: '1px solid var(--border)',
              background: 'var(--bg-elevated)', flexShrink: 0,
              display: 'flex', flexDirection: 'column', gap: 10,
            }}>
              {/* Reassign (only if driver has active order) */}
              {driver.active_order_id && (
                <div>
                  <button
                    className="btn btn-ghost btn-sm"
                    style={{ width: '100%', justifyContent: 'space-between' }}
                    onClick={() => setReassignExpanded(v => !v)}
                  >
                    <span>Reassign Active Order</span>
                    <ChevronRight size={14} style={{ transform: reassignExpanded ? 'rotate(90deg)' : 'none', transition: 'transform 0.15s' }} />
                  </button>
                  {reassignExpanded && (
                    <div style={{ display: 'flex', gap: 8, marginTop: 8 }}>
                      <select
                        value={newDriverId}
                        onChange={e => setNewDriverId(e.target.value)}
                        style={{
                          flex: 1, padding: '7px 10px', borderRadius: 'var(--r-md)',
                          border: '1px solid var(--border)', background: 'var(--bg-surface)',
                          color: 'var(--text-primary)', fontSize: 13, outline: 'none',
                        }}
                      >
                        <option value="">Select driver…</option>
                        {availableForReassign.map(d => (
                          <option key={d.id} value={d.id}>{d.name} ({d.vehicle_plate})</option>
                        ))}
                      </select>
                      <button
                        className="btn btn-primary btn-sm"
                        disabled={!newDriverId || reassignLoading}
                        onClick={() => { onReassign(newDriverId); setNewDriverId(''); setReassignExpanded(false); }}
                      >
                        {reassignLoading ? '…' : 'Go'}
                      </button>
                    </div>
                  )}
                </div>
              )}

              {/* Suspend / Reactivate */}
              <button
                className={`btn btn-sm ${status === 'suspended' ? 'btn-success' : 'btn-danger'}`}
                style={{ width: '100%' }}
                disabled={suspendLoading}
                onClick={() => onSuspend(status === 'suspended' ? 'offline' : 'suspended')}
              >
                {suspendLoading ? '…' : status === 'suspended' ? 'Reactivate Driver' : 'Suspend Driver'}
              </button>
            </div>
          </>
        )}
      </div>
    </>
  );
};

/* ─── DriversPage ────────────────────────────────────────────────────────── */
const DriversPage = () => {
  const [drivers,         setDrivers]         = useState([]);
  const [loading,         setLoading]         = useState(true);
  const [filter,          setFilter]          = useState('all');
  const [search,          setSearch]          = useState('');
  const [selectedDriver,  setSelectedDriver]  = useState(null);
  const [drawerDetail,    setDrawerDetail]    = useState(null);
  const [drawerLoading,   setDrawerLoading]   = useState(false);
  const [suspendLoading,  setSuspendLoading]  = useState(false);
  const [reassignLoading, setReassignLoading] = useState(false);

  const loadDrivers = useCallback(async () => {
    setLoading(true);
    try {
      const r = await driverAPI.getAllAdmin();
      setDrivers(r.data.drivers || []);
    } catch {
      toast.error('Failed to load drivers');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { loadDrivers(); }, [loadDrivers]);

  const handleSelectDriver = async (d) => {
    setSelectedDriver(d);
    setDrawerDetail(null);
    setDrawerLoading(true);
    try {
      const r = await driverAPI.getDetailAdmin(d.id);
      setDrawerDetail(r.data);
    } catch {
      toast.error('Failed to load driver details');
    } finally {
      setDrawerLoading(false);
    }
  };

  const handleSuspend = async (newStatus) => {
    if (!selectedDriver) return;
    setSuspendLoading(true);
    try {
      await driverAPI.updateStatusAdmin(selectedDriver.id, newStatus);
      toast.success(`Driver ${newStatus === 'suspended' ? 'suspended' : 'reactivated'}`);
      await loadDrivers();
      setSelectedDriver(prev => ({ ...prev, status: newStatus }));
    } catch {
      toast.error('Failed to update driver status');
    } finally {
      setSuspendLoading(false);
    }
  };

  const handleReassign = async (newDriverId) => {
    if (!selectedDriver) return;
    setReassignLoading(true);
    try {
      await driverAPI.reassignAdmin(selectedDriver.id, { new_driver_id: newDriverId });
      toast.success('Order reassigned');
      await loadDrivers();
      setSelectedDriver(null);
    } catch {
      toast.error('Failed to reassign order');
    } finally {
      setReassignLoading(false);
    }
  };

  /* ── derived stats ── */
  const activeNow = useMemo(() => drivers.filter(d => ['available', 'on_delivery'].includes(effectiveStatus(d))).length, [drivers]);
  const todayTotal = useMemo(() => drivers.reduce((s, d) => s + (parseInt(d.today_deliveries) || 0), 0), [drivers]);
  const avgRating = useMemo(() => {
    const valid = drivers.filter(d => parseFloat(d.avg_rating) > 0);
    return valid.length ? (valid.reduce((s, d) => s + parseFloat(d.avg_rating), 0) / valid.length).toFixed(1) : '—';
  }, [drivers]);
  const unverified = useMemo(() => drivers.filter(d => !d.is_verified).length, [drivers]);

  /* ── filter + search ── */
  const filtered = useMemo(() => {
    const q = search.toLowerCase();
    return drivers.filter(d => {
      const matchFilter = filter === 'all' ? true : effectiveStatus(d) === filter;
      const matchSearch = !search ||
        (d.name  || '').toLowerCase().includes(q) ||
        (d.phone || '').includes(q);
      return matchFilter && matchSearch;
    });
  }, [drivers, filter, search]);

  const filterCount = useMemo(() => (f) =>
    f === 'all' ? drivers.length : drivers.filter(d => effectiveStatus(d) === f).length,
  [drivers]);

  return (
    <DashboardLayout>

      {/* ── header ── */}
      <div className="page-header">
        <div>
          <h1 className="page-title">Driver Management</h1>
          <p className="page-subtitle">Live fleet status, location tracking and account management</p>
        </div>
        <button className="btn btn-ghost" onClick={loadDrivers} disabled={loading}>
          <RefreshCw size={13} style={{ animation: loading ? 'spin 0.65s linear infinite' : 'none' }} />
          Refresh
        </button>
      </div>

      {/* ── stats row ── */}
      <div className="dash-row-stats" style={{ marginBottom: 'var(--grid-gap)' }}>
        {/* Hero: Active Now */}
        <div className="hero-card">
          <p className="stat-label">Active Drivers Now</p>
          <div>
            <p className="stat-value">{loading ? '—' : activeNow}</p>
            <p className="stat-sub" style={{ marginTop: 8 }}>
              {drivers.filter(d => effectiveStatus(d) === 'available').length} available ·{' '}
              {drivers.filter(d => effectiveStatus(d) === 'on_delivery').length} on delivery
            </p>
          </div>
        </div>

        <div className="stat-card">
          <p className="stat-label">Deliveries Today</p>
          <p className="stat-value" style={{ fontSize: 28 }}>{loading ? '—' : todayTotal}</p>
          <p className="stat-sub">Across all drivers</p>
        </div>

        <div className="stat-card">
          <p className="stat-label">Fleet Avg Rating</p>
          <p className="stat-value" style={{ fontSize: 28 }}>{loading ? '—' : avgRating}</p>
          <p className="stat-sub">From completed orders</p>
        </div>

        <div className="stat-card">
          <p className="stat-label">Unverified</p>
          <p className="stat-value" style={{ fontSize: 28, color: unverified > 0 ? 'var(--accent-negative)' : 'inherit' }}>
            {loading ? '—' : unverified}
          </p>
          <p className="stat-sub">Pending admin review</p>
        </div>
      </div>

      {/* ── main 8/4 grid ── */}
      <div style={{ display: 'grid', gridTemplateColumns: '8fr 4fr', gap: 'var(--grid-gap)', alignItems: 'start' }}>

        {/* ── left: driver list ── */}
        <div>
          {/* toolbar */}
          <div style={{ display: 'flex', gap: 10, marginBottom: 14 }}>
            <div style={{
              flex: 1, display: 'flex', alignItems: 'center', gap: 8,
              background: 'var(--bg-surface)', border: '1px solid var(--border)',
              borderRadius: 'var(--r-md)', padding: '0 12px', height: 36,
            }}>
              <Search size={13} style={{ color: 'var(--text-secondary)', flexShrink: 0 }} />
              <input
                style={{ flex: 1, border: 'none', background: 'transparent', outline: 'none', fontSize: 13, color: 'var(--text-primary)' }}
                placeholder="Search by name or phone…"
                value={search}
                onChange={e => setSearch(e.target.value)}
              />
              {search && (
                <button style={{ border: 'none', background: 'transparent', cursor: 'pointer', color: 'var(--text-secondary)', display: 'flex' }} onClick={() => setSearch('')}>
                  <X size={12} />
                </button>
              )}
            </div>
          </div>

          {/* filter pills */}
          <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginBottom: 16 }}>
            {FILTERS.map(f => (
              <button
                key={f}
                className={`filter-pill${filter === f ? ' active' : ''}`}
                onClick={() => setFilter(f)}
              >
                {f === 'all' ? 'All Drivers' : STATUS_CFG[f]?.label || f}
                <span style={{ marginLeft: 5, opacity: 0.55, fontWeight: 400 }}>{filterCount(f)}</span>
              </button>
            ))}
          </div>

          {/* table */}
          <div className="card fade-in" style={{ padding: 0 }}>
            {/* table head */}
            <div className="table-head-row" style={{ gridTemplateColumns: '2.4fr 1.5fr 1.1fr 0.65fr 0.65fr 28px' }}>
              <span>Driver</span>
              <span>Status</span>
              <span>Motorbike</span>
              <span>Today</span>
              <span>Rating</span>
              <span />
            </div>

            {loading ? (
              <div className="loading-center" style={{ padding: '40px 0' }}><div className="spinner" /></div>
            ) : filtered.length === 0 ? (
              <div className="empty-state">
                <AlertCircle size={24} className="empty-icon" />
                <p className="empty-title">
                  {search
                    ? 'No drivers match your search'
                    : filter !== 'all'
                    ? `No ${STATUS_CFG[filter]?.label?.toLowerCase()} drivers right now`
                    : 'No drivers registered yet'}
                </p>
                <p className="empty-sub">
                  {search ? 'Try a different name or phone number.' : 'Drivers will appear here once registered.'}
                </p>
              </div>
            ) : (
              filtered.map(d => (
                <DriverRow
                  key={d.id}
                  driver={d}
                  isSelected={selectedDriver?.id === d.id}
                  onSelect={handleSelectDriver}
                />
              ))
            )}
          </div>
        </div>

        {/* ── right: live map ── */}
        <LiveMap
          drivers={filtered}
          selectedId={selectedDriver?.id}
          onSelectDriver={handleSelectDriver}
          filter={filter}
        />
      </div>

      {/* ── side drawer ── */}
      <DriverDrawer
        driver={selectedDriver}
        detail={drawerDetail}
        loading={drawerLoading}
        onClose={() => setSelectedDriver(null)}
        onSuspend={handleSuspend}
        onReassign={handleReassign}
        allDrivers={drivers}
        suspendLoading={suspendLoading}
        reassignLoading={reassignLoading}
      />
    </DashboardLayout>
  );
};

export default DriversPage;
