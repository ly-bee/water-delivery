import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { toast } from 'react-toastify';
import { useAuth } from '../../context/AuthContext';
import { Waves, Phone, Lock, Eye, EyeOff } from 'lucide-react';

const LoginPage = () => {
  const [phone,       setPhone]       = useState('');
  const [password,    setPassword]    = useState('');
  const [showPass,    setShowPass]    = useState(false);
  const [loading,     setLoading]     = useState(false);
  const { login }  = useAuth();
  const navigate   = useNavigate();

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!phone || !password) { toast.error('Enter phone and password'); return; }
    setLoading(true);
    const result = await login(phone, password);
    setLoading(false);
    if (result.success) {
      toast.success(`Welcome, ${result.user.name}!`);
      const role = result.user.role;
      if (role === 'resident') { toast.error('Residents must use the mobile app.'); return; }
      navigate(role === 'driver' ? '/orders' : '/dashboard');
    } else {
      toast.error(result.message);
    }
  };

  return (
    <div className="login-page">

      {/* ── Brand panel ─────────────────────────────────────────────────── */}
      <div className="login-brand">
        <div className="login-brand-glow" style={{ width: 360, height: 360, top: -120, left: -120 }} />
        <div className="login-brand-glow" style={{ width: 220, height: 220, bottom: 40, right: -60, background: 'rgba(255,255,255,0.03)' }} />

        {/* Logo */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 'auto', position: 'relative' }}>
          <div style={{
            width: 34, height: 34, background: 'rgba(255,255,255,0.12)',
            border: '1px solid rgba(255,255,255,0.15)',
            borderRadius: 8,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <Waves size={18} color="#fff" />
          </div>
          <div>
            <div style={{ fontSize: 16, fontWeight: 700, color: '#fff', letterSpacing: '-0.2px' }}>HydroFlow</div>
            <div style={{ fontSize: 10, color: 'rgba(255,255,255,0.35)', textTransform: 'uppercase', letterSpacing: '0.08em', fontWeight: 600 }}>Admin Console</div>
          </div>
        </div>

        {/* Headline */}
        <div style={{ position: 'relative', paddingTop: 48 }}>
          <h1 style={{ fontSize: 34, fontWeight: 700, color: '#fff', letterSpacing: '-0.5px', lineHeight: 1.2, marginBottom: 12 }}>
            Smart Water<br />Delivery,<br />
            <span style={{ opacity: 0.5 }}>Managed.</span>
          </h1>
          <p style={{ fontSize: 14, color: 'rgba(255,255,255,0.38)', lineHeight: 1.65, maxWidth: 280 }}>
            Operations hub for your HydroFlow delivery network — orders, drivers, and analytics in one place.
          </p>
        </div>

        {/* Feature list */}
        <div style={{ position: 'relative', marginTop: 40, display: 'flex', flexDirection: 'column', gap: 12 }}>
          {[
            'Real-time order tracking & management',
            'Fleet performance analytics',
            'Live driver location monitoring',
          ].map(t => (
            <div key={t} style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
              <div style={{ width: 4, height: 4, borderRadius: '50%', background: 'rgba(255,255,255,0.3)', flexShrink: 0 }} />
              <span style={{ fontSize: 13, color: 'rgba(255,255,255,0.4)' }}>{t}</span>
            </div>
          ))}
        </div>

        <p style={{ position: 'relative', fontSize: 11, color: 'rgba(255,255,255,0.18)', marginTop: 48 }}>
          © {new Date().getFullYear()} HydroFlow Technologies
        </p>
      </div>

      {/* ── Form panel ──────────────────────────────────────────────────── */}
      <div className="login-form-side">
        <div className="login-form-box">
          <h2 style={{ fontSize: 22, fontWeight: 700, color: 'var(--text-primary)', letterSpacing: '-0.3px', marginBottom: 4 }}>
            Welcome back
          </h2>
          <p style={{ fontSize: 13, color: 'var(--text-secondary)', marginBottom: 28 }}>
            Sign in to your admin account to continue.
          </p>

          <form onSubmit={handleSubmit}>
            {/* Phone */}
            <div style={{ marginBottom: 16 }}>
              <label className="login-label">Phone Number</label>
              <div className="login-input-wrap">
                <span className="login-input-icon"><Phone size={14} /></span>
                <input className="login-input" type="text" placeholder="0712 345 678"
                  value={phone} onChange={e => setPhone(e.target.value)} autoComplete="tel" />
              </div>
            </div>

            {/* Password */}
            <div style={{ marginBottom: 24 }}>
              <label className="login-label">Password</label>
              <div className="login-input-wrap">
                <span className="login-input-icon"><Lock size={14} /></span>
                <input className="login-input" type={showPass ? 'text' : 'password'}
                  placeholder="Enter your password" value={password}
                  onChange={e => setPassword(e.target.value)}
                  style={{ paddingRight: 40 }} autoComplete="current-password" />
                <button type="button" className="login-eye-btn" onClick={() => setShowPass(v => !v)}>
                  {showPass ? <EyeOff size={14} /> : <Eye size={14} />}
                </button>
              </div>
            </div>

            <button type="submit" className="login-submit" disabled={loading}>
              {loading ? 'Signing in…' : 'Sign In'}
            </button>
          </form>

          <p style={{ textAlign: 'center', marginTop: 24, fontSize: 12, color: 'var(--text-secondary)' }}>
            Residents &amp; drivers should use the&nbsp;
            <strong style={{ color: 'var(--text-primary)', fontWeight: 600 }}>HydroFlow Mobile App</strong>
          </p>
        </div>
      </div>
    </div>
  );
};

export default LoginPage;
