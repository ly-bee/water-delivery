import { useEffect, useState, useCallback } from 'react';
import { useSearchParams, useNavigate } from 'react-router-dom';
import { Waves, CheckCircle, XCircle, Loader } from 'lucide-react';
import { authAPI } from '../../services/api';

// ─────────────────────────────────────────
// VERIFY EMAIL PAGE
// Handles email verification link clicks
// ─────────────────────────────────────────
const VerifyEmailPage = () => {
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const [status, setStatus] = useState('loading'); // loading | success | error
  const [message, setMessage] = useState('');

  // ✅ Defined before useEffect and wrapped in useCallback
  // so it's a stable reference safe to list in the deps array
  const verifyToken = useCallback(async (token) => {
    try {
      const response = await authAPI.verifyEmail(token);
      setStatus('success');
      setMessage(response.data.message);

      // Auto redirect to login after 3 seconds
      setTimeout(() => navigate('/login'), 3000);
    } catch (error) {
      setStatus('error');
      setMessage(
        error.response?.data?.message ||
        'Verification failed. The link may have expired.'
      );
    }
  }, [navigate]);

  // ✅ Both searchParams and verifyToken are now stable refs — safe in deps array
  useEffect(() => {
    const token = searchParams.get('token');
    if (!token) {
      setStatus('error');
      setMessage('Invalid verification link.');
      return;
    }
    verifyToken(token);
  }, [searchParams, verifyToken]);

  return (
    <div style={{
      minHeight: '100vh',
      background: 'linear-gradient(135deg, #EFF6FF 0%, #F8FAFC 50%, #EFF6FF 100%)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      padding: '20px',
    }}>
      <div style={{
        background: '#FFFFFF',
        borderRadius: '16px',
        padding: '48px',
        width: '100%',
        maxWidth: '420px',
        boxShadow: '0 4px 24px rgba(59, 130, 246, 0.08)',
        textAlign: 'center',
      }}>
        {/* Logo */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '10px', marginBottom: '32px' }}>
          <Waves size={28} color="#3B82F6" />
          <span style={{ fontSize: '24px', fontWeight: '700', color: '#3B82F6' }}>HydroFlow</span>
        </div>

        {/* Loading */}
        {status === 'loading' && (
          <>
            <Loader size={48} color="#3B82F6" style={{ animation: 'spin 1s linear infinite' }} />
            <h2 style={{ margin: '16px 0 8px', color: '#1E293B', fontSize: '20px' }}>
              Verifying your email...
            </h2>
            <p style={{ color: '#64748B', fontSize: '14px' }}>
              Please wait a moment.
            </p>
          </>
        )}

        {/* Success */}
        {status === 'success' && (
          <>
            <CheckCircle size={48} color="#10B981" />
            <h2 style={{ margin: '16px 0 8px', color: '#1E293B', fontSize: '20px' }}>
              Email Verified! 🎉
            </h2>
            <p style={{ color: '#64748B', fontSize: '14px', marginBottom: '24px' }}>
              {message}
            </p>
            <p style={{ color: '#94A3B8', fontSize: '13px' }}>
              Redirecting to login in 3 seconds...
            </p>
          </>
        )}

        {/* Error */}
        {status === 'error' && (
          <>
            <XCircle size={48} color="#EF4444" />
            <h2 style={{ margin: '16px 0 8px', color: '#1E293B', fontSize: '20px' }}>
              Verification Failed
            </h2>
            <p style={{ color: '#64748B', fontSize: '14px', marginBottom: '24px' }}>
              {message}
            </p>
            <button
              onClick={() => navigate('/login')}
              style={{
                padding: '12px 32px',
                background: '#3B82F6',
                color: '#FFFFFF',
                border: 'none',
                borderRadius: '8px',
                fontSize: '14px',
                fontWeight: '600',
                cursor: 'pointer',
              }}
            >
              Back to Login
            </button>
          </>
        )}
      </div>
    </div>
  );
};

export default VerifyEmailPage;