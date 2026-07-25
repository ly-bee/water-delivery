import { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { toast } from 'react-toastify';
import { useAuth } from '../../context/AuthContext';
import { Waves, Phone, Lock, Eye, EyeOff, User, Mail, Shield } from 'lucide-react';

const styles = {
  page: {
    minHeight: '100vh',
    background: 'linear-gradient(135deg, #EFF6FF 0%, #F8FAFC 50%, #EFF6FF 100%)',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    padding: '20px'
  },
  card: {
    background: '#FFFFFF',
    borderRadius: '16px',
    padding: '48px',
    width: '100%',
    maxWidth: '420px',
    boxShadow: '0 4px 24px rgba(59, 130, 246, 0.08)'
  },
  logoSection: {
    display: 'flex',
    alignItems: 'center',
    gap: '12px',
    marginBottom: '8px'
  },
  logoText: {
    fontSize: '28px',
    fontWeight: '700',
    color: '#3B82F6'
  },
  subtitle: {
    fontSize: '14px',
    color: '#64748B',
    marginBottom: '32px'
  },
  formGroup: {
    marginBottom: '20px'
  },
  label: {
    display: 'block',
    fontSize: '14px',
    fontWeight: '500',
    color: '#374151',
    marginBottom: '6px'
  },
  inputWrapper: {
    position: 'relative',
    display: 'flex',
    alignItems: 'center'
  },
  inputIcon: {
    position: 'absolute',
    left: '12px',
    color: '#94A3B8'
  },
  input: {
    width: '100%',
    padding: '12px 12px 12px 40px',
    border: '1px solid #E2E8F0',
    borderRadius: '8px',
    fontSize: '14px',
    color: '#1E293B',
    background: '#F8FAFC',
    outline: 'none',
    boxSizing: 'border-box',
  },
  select: {
    width: '100%',
    padding: '12px 12px 12px 40px',
    border: '1px solid #E2E8F0',
    borderRadius: '8px',
    fontSize: '14px',
    color: '#1E293B',
    background: '#F8FAFC',
    outline: 'none',
    boxSizing: 'border-box',
    cursor: 'pointer',
  },
  eyeBtn: {
    position: 'absolute',
    right: '12px',
    background: 'none',
    border: 'none',
    cursor: 'pointer',
    color: '#94A3B8',
    padding: '0'
  },
  submitBtn: {
    width: '100%',
    padding: '13px',
    background: '#3B82F6',
    color: '#FFFFFF',
    border: 'none',
    borderRadius: '8px',
    fontSize: '15px',
    fontWeight: '600',
    cursor: 'pointer',
    marginTop: '8px',
    transition: 'background 0.15s ease'
  },
  submitBtnDisabled: {
    width: '100%',
    padding: '13px',
    background: '#93C5FD',
    color: '#FFFFFF',
    border: 'none',
    borderRadius: '8px',
    fontSize: '15px',
    fontWeight: '600',
    cursor: 'not-allowed',
    marginTop: '8px'
  },
  loginLink: {
    textAlign: 'center',
    marginTop: '20px',
    fontSize: '14px',
    color: '#64748B'
  },
  link: {
    color: '#3B82F6',
    fontWeight: '600',
    textDecoration: 'none',
    marginLeft: '4px'
  },
  notice: {
    background: '#FFF7ED',
    border: '1px solid #FED7AA',
    borderRadius: '8px',
    padding: '12px',
    marginBottom: '24px',
    fontSize: '13px',
    color: '#C2410C',
  }
};

const SignupPage = () => {
  const [form, setForm] = useState({
    name: '',
    phone: '',
    email: '',
    password: '',
    role: 'driver',
  });
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);

  const { signup } = useAuth();
  const navigate = useNavigate();

  const handleChange = (e) => {
    setForm({ ...form, [e.target.name]: e.target.value });
  };

  const handleSubmit = async (e) => {
    e.preventDefault();

    if (!form.name || !form.phone || !form.password) {
      toast.error('Name, phone and password are required');
      return;
    }

    if (form.password.length < 6) {
      toast.error('Password must be at least 6 characters');
      return;
    }

    setLoading(true);
    const result = await signup(form);
    setLoading(false);

    if (result.success) {
      toast.success(`Welcome, ${result.user.name}!`);
      const role = result.user.role;
      if (role === 'driver') {
        navigate('/orders');
      } else {
        navigate('/dashboard');
      }
    } else {
      toast.error(result.message);
    }
  };

  return (
    <div style={styles.page}>
      <div style={styles.card}>

        {/* Logo */}
        <div style={styles.logoSection}>
          <Waves size={32} color="#3B82F6" />
          <span style={styles.logoText}>HydroFlow</span>
        </div>
        <p style={styles.subtitle}>Create a staff account</p>

        {/* Notice */}
        <div style={styles.notice}>
          🔒 This portal is for <strong>drivers</strong> and <strong>admins</strong> only.
          Residents must use the mobile app.
        </div>

        {/* Form */}
        <form onSubmit={handleSubmit}>

          {/* Name */}
          <div style={styles.formGroup}>
            <label style={styles.label}>Full Name</label>
            <div style={styles.inputWrapper}>
              <span style={styles.inputIcon}><User size={16} /></span>
              <input
                name="name"
                type="text"
                placeholder="John Doe"
                value={form.name}
                onChange={handleChange}
                style={styles.input}
              />
            </div>
          </div>

          {/* Phone */}
          <div style={styles.formGroup}>
            <label style={styles.label}>Phone Number</label>
            <div style={styles.inputWrapper}>
              <span style={styles.inputIcon}><Phone size={16} /></span>
              <input
                name="phone"
                type="text"
                placeholder="0712345678"
                value={form.phone}
                onChange={handleChange}
                style={styles.input}
              />
            </div>
          </div>

          {/* Email */}
          <div style={styles.formGroup}>
            <label style={styles.label}>Email (optional)</label>
            <div style={styles.inputWrapper}>
              <span style={styles.inputIcon}><Mail size={16} /></span>
              <input
                name="email"
                type="email"
                placeholder="john@example.com"
                value={form.email}
                onChange={handleChange}
                style={styles.input}
              />
            </div>
          </div>

          {/* Password */}
          <div style={styles.formGroup}>
            <label style={styles.label}>Password</label>
            <div style={styles.inputWrapper}>
              <span style={styles.inputIcon}><Lock size={16} /></span>
              <input
                name="password"
                type={showPassword ? 'text' : 'password'}
                placeholder="Min 6 characters"
                value={form.password}
                onChange={handleChange}
                style={styles.input}
              />
              <button
                type="button"
                style={styles.eyeBtn}
                onClick={() => setShowPassword(!showPassword)}
              >
                {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
              </button>
            </div>
          </div>

          {/* Role */}
          <div style={styles.formGroup}>
            <label style={styles.label}>Role</label>
            <div style={styles.inputWrapper}>
              <span style={styles.inputIcon}><Shield size={16} /></span>
              <select
                name="role"
                value={form.role}
                onChange={handleChange}
                style={styles.select}
              >
                <option value="driver">Driver</option>
                <option value="admin">Admin</option>
              </select>
            </div>
          </div>

          {/* Submit */}
          <button
            type="submit"
            disabled={loading}
            style={loading ? styles.submitBtnDisabled : styles.submitBtn}
          >
            {loading ? 'Creating Account...' : 'Create Account'}
          </button>

        </form>

        {/* Login Link */}
        <div style={styles.loginLink}>
          Already have an account?
          <Link to="/login" style={styles.link}>Sign In</Link>
        </div>

      </div>
    </div>
  );
};

export default SignupPage;