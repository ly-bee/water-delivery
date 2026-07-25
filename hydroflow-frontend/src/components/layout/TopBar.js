import { useState, useRef, useEffect } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { useAuth } from '../../context/AuthContext';
import { Waves, ChevronRight, ChevronDown, Sun, Moon, Bell, LogOut } from 'lucide-react';

const PAGE_LABELS = {
  '/dashboard': 'Dashboard',
  '/orders':    'Orders',
  '/drivers':   'Drivers',
  '/users':     'Users',
};

function initials(name = '') {
  const p = (name || '').trim().split(' ');
  return p.length >= 2 ? (p[0][0] + p[1][0]).toUpperCase() : ((name || '')[0] || '?').toUpperCase();
}

function getSystemTheme() {
  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

const TopBar = () => {
  const { user, logout } = useAuth();
  const location = useLocation();
  const navigate = useNavigate();
  const [dropdownOpen, setDropdownOpen] = useState(false);
  const dropdownRef = useRef(null);

  const [theme, setTheme] = useState(() => localStorage.getItem('aq-theme') || 'system');
  const isDark = theme === 'system' ? getSystemTheme() === 'dark' : theme === 'dark';

  const toggleTheme = () => {
    const current = theme === 'system' ? getSystemTheme() : theme;
    const next = current === 'dark' ? 'light' : 'dark';
    setTheme(next);
    localStorage.setItem('aq-theme', next);
    document.documentElement.setAttribute('data-theme', next);
  };

  useEffect(() => {
    const handler = (e) => {
      if (dropdownRef.current && !dropdownRef.current.contains(e.target)) {
        setDropdownOpen(false);
      }
    };
    document.addEventListener('mousedown', handler);
    return () => document.removeEventListener('mousedown', handler);
  }, []);

  const pageLabel = PAGE_LABELS[location.pathname] || 'HydroFlow';

  return (
    <header className="topbar">
      {/* breadcrumb */}
      <nav className="topbar-breadcrumb" aria-label="Breadcrumb">
        <Waves size={14} style={{ color: 'var(--text-secondary)', flexShrink: 0 }} />
        <ChevronRight size={12} style={{ color: 'var(--border)', flexShrink: 0 }} />
        <span className="topbar-bc-page">{pageLabel}</span>
      </nav>

      {/* right actions */}
      <div className="topbar-right">
        <button
          className="topbar-icon-btn"
          onClick={toggleTheme}
          title={isDark ? 'Switch to light mode' : 'Switch to dark mode'}
        >
          {isDark ? <Sun size={16} /> : <Moon size={16} />}
        </button>

        <button className="topbar-icon-btn" title="Notifications">
          <Bell size={16} />
          <span className="topbar-notif-dot" />
        </button>

        <div className="topbar-divider" />

        <div className="topbar-user-wrap" ref={dropdownRef}>
          <button
            className="topbar-user-btn"
            onClick={() => setDropdownOpen(v => !v)}
          >
            <div className="topbar-avatar">{initials(user?.name)}</div>
            <div className="topbar-user-info">
              <span className="topbar-user-name">{user?.name || 'Admin'}</span>
              <span className="topbar-user-role">{user?.role || 'admin'}</span>
            </div>
            <ChevronDown
              size={13}
              style={{
                color: 'var(--text-secondary)',
                transition: 'transform 0.15s',
                transform: dropdownOpen ? 'rotate(180deg)' : 'none',
                flexShrink: 0,
              }}
            />
          </button>

          {dropdownOpen && (
            <div className="topbar-dropdown">
              <div className="topbar-dropdown-header">
                <div className="topbar-avatar topbar-avatar-lg">{initials(user?.name)}</div>
                <div>
                  <p className="topbar-dd-name">{user?.name || 'Admin'}</p>
                  <p className="topbar-dd-sub">{user?.email || user?.phone || ''}</p>
                </div>
              </div>
              <div className="topbar-dropdown-divider" />
              <button
                className="topbar-dropdown-item topbar-dropdown-item--danger"
                onClick={() => { setDropdownOpen(false); logout(); navigate('/login'); }}
              >
                <LogOut size={13} /> Sign out
              </button>
            </div>
          )}
        </div>
      </div>
    </header>
  );
};

export default TopBar;
