import { NavLink } from 'react-router-dom';
import { useAuth } from '../../context/AuthContext';
import { LayoutDashboard, ShoppingCart, Motorbike, Users, Waves } from 'lucide-react';

const NAV = [
  { to: '/dashboard', icon: LayoutDashboard, label: 'Dashboard', roles: ['admin'] },
  { to: '/orders',    icon: ShoppingCart,    label: 'Orders',    roles: ['admin', 'driver'] },
  { to: '/drivers',   icon: Motorbike,       label: 'Drivers',   roles: ['admin'] },
  { to: '/users',     icon: Users,           label: 'Users',     roles: ['admin'] },
];

const Sidebar = () => {
  const { user } = useAuth();
  const role = user?.role || '';

  return (
    <div className="sidebar">
      <div className="sidebar-logo">
        <div className="sidebar-logo-mark">
          <Waves size={15} color="var(--btn-text)" />
        </div>
        <div>
          <div className="sidebar-logo-name">HydroFlow</div>
          <div className="sidebar-logo-sub">Admin Console</div>
        </div>
      </div>

      <nav className="sidebar-nav">
        <p className="sidebar-section">Main</p>
        {NAV.filter(n => n.roles.includes(role)).map(({ to, icon: Icon, label }) => (
          <NavLink
            key={to}
            to={to}
            className={({ isActive }) => `nav-item${isActive ? ' active' : ''}`}
          >
            <Icon size={15} />
            {label}
          </NavLink>
        ))}
      </nav>
    </div>
  );
};

export default Sidebar;
