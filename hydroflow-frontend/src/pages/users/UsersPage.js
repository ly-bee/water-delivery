import { useState, useEffect, useMemo } from 'react';
import { toast } from 'react-toastify';
import { Search, RefreshCw } from 'lucide-react';
import DashboardLayout from '../../components/layout/DashboardLayout';
import { userAPI } from '../../services/api';

const ROLE_BADGE = { admin: 'badge-admin', driver: 'badge-driver', resident: 'badge-resident' };

function initials(name = '') {
  const p = name.trim().split(' ');
  return p.length >= 2 ? (p[0][0] + p[1][0]).toUpperCase() : (name[0] || '?').toUpperCase();
}

const UsersPage = () => {
  const [users,      setUsers]      = useState([]);
  const [loading,    setLoading]    = useState(true);
  const [search,     setSearch]     = useState('');
  const [roleFilter, setRoleFilter] = useState('ALL');

  const loadUsers = async () => {
    setLoading(true);
    try { const r = await userAPI.getAll(); setUsers(r.data.users || []); }
    catch { toast.error('Failed to load users'); }
    finally { setLoading(false); }
  };

  useEffect(() => { loadUsers(); }, []);

  const filtered = useMemo(() => {
    const q = search.toLowerCase();
    return users.filter(u => {
      const matchRole   = roleFilter === 'ALL' || u.role === roleFilter.toLowerCase();
      const matchSearch = !search || u.name.toLowerCase().includes(q) || u.phone.includes(q) || (u.email||'').toLowerCase().includes(q);
      return matchRole && matchSearch;
    });
  }, [users, search, roleFilter]);

  const residents = useMemo(() => users.filter(u => u.role === 'resident').length, [users]);
  const drivers   = useMemo(() => users.filter(u => u.role === 'driver').length, [users]);
  const admins    = useMemo(() => users.filter(u => u.role === 'admin').length, [users]);

  const COL = 'gridTemplateColumns';

  return (
    <DashboardLayout>
      <div className="page-header">
        <div>
          <h1 className="page-title">Users</h1>
          <p className="page-subtitle">All registered HydroFlow accounts</p>
        </div>
        <button className="btn btn-ghost" onClick={loadUsers} disabled={loading}>
          <RefreshCw size={13} style={{ animation: loading ? 'spin 0.65s linear infinite' : 'none' }} />
          Refresh
        </button>
      </div>

      {/* Stats */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4,1fr)', gap: 'var(--grid-gap)', marginBottom: 'var(--grid-gap)' }}>
        {[
          { label: 'Total Users', value: users.length },
          { label: 'Residents',   value: residents    },
          { label: 'Drivers',     value: drivers      },
          { label: 'Admins',      value: admins       },
        ].map(s => (
          <div key={s.label} className="stat-card">
            <p className="stat-label">{s.label}</p>
            <p className="stat-value" style={{ fontSize: 28 }}>{s.value}</p>
          </div>
        ))}
      </div>

      {/* Toolbar */}
      <div style={{ display: 'flex', gap: 8, marginBottom: 16, flexWrap: 'wrap', alignItems: 'center' }}>
        <div className="input-wrap" style={{ flex: 1, maxWidth: 320 }}>
          <span className="input-icon"><Search size={14} /></span>
          <input className="input" type="text" placeholder="Search by name, phone or email…" value={search} onChange={e => setSearch(e.target.value)} />
        </div>
        <div className="filter-bar" style={{ margin: 0 }}>
          {['ALL','RESIDENT','DRIVER','ADMIN'].map(r => (
            <button key={r} className={`filter-pill${roleFilter===r?' active':''}`} onClick={() => setRoleFilter(r)}>
              {r === 'ALL' ? 'All' : r.charAt(0) + r.slice(1).toLowerCase() + 's'}
            </button>
          ))}
        </div>
      </div>

      {/* Table */}
      <div className="card fade-in">
        <div className="table-head-row" style={{ [COL]: '2.5fr 1.4fr 2fr 100px 80px' }}>
          <span>User</span><span>Phone</span><span>Email</span><span>Role</span><span>Verified</span>
        </div>

        {loading ? (
          <div className="loading-center" style={{ height: 240 }}><div className="spinner" /></div>
        ) : filtered.length === 0 ? (
          <div className="empty-state">
            <p className="empty-title">No users found</p>
            <p className="empty-sub">Try adjusting your search or filter.</p>
          </div>
        ) : filtered.map(u => (
          <div key={u.id} className="table-data-row" style={{ [COL]: '2.5fr 1.4fr 2fr 100px 80px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
              <div className="avatar">{initials(u.name)}</div>
              <div>
                <p style={{ fontSize: 13, fontWeight: 600, color: 'var(--text-primary)', margin: 0 }}>{u.name}</p>
                <p style={{ fontSize: 11, color: 'var(--text-secondary)', margin: '1px 0 0' }}>
                  {new Date(u.created_at).toLocaleDateString('en', { month: 'short', day: 'numeric', year: 'numeric' })}
                </p>
              </div>
            </div>
            <p style={{ fontSize: 13, color: 'var(--text-secondary)', margin: 0 }}>{u.phone}</p>
            <p style={{ fontSize: 12, color: 'var(--text-secondary)', margin: 0, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
              {u.email || <span style={{ color: 'var(--border)' }}>—</span>}
            </p>
            <span className={`badge ${ROLE_BADGE[u.role]||'badge-cancelled'}`}>{u.role}</span>
            <span style={{ fontSize: 12, fontWeight: 600, color: u.is_verified ? 'var(--accent-positive)' : 'var(--text-secondary)' }}>
              {u.is_verified ? '✓ Yes' : '✗ No'}
            </span>
          </div>
        ))}
      </div>
    </DashboardLayout>
  );
};

export default UsersPage;
