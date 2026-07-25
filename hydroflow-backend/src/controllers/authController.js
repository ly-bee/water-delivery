const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { pool } = require('../config/db');
const { sendVerificationEmail, sendWelcomeEmail } = require('../services/emailService');
const { sendOtpSms } = require('../services/smsService');

// ─────────────────────────────────────────
// REGISTER  POST /api/auth/register
// ─────────────────────────────────────────
const register = async (req, res) => {
  try {
    const { name, phone, email, password, role } = req.body;

    if (!name || !phone || !password) {
      return res.status(400).json({ error: 'MISSING_FIELDS', message: 'Name, phone and password are required' });
    }
    if (!email) {
      return res.status(400).json({ error: 'MISSING_EMAIL', message: 'Email is required for account verification' });
    }

    const existingPhone = await pool.query('SELECT id FROM users WHERE phone = $1', [phone]);
    if (existingPhone.rows.length > 0) {
      return res.status(409).json({ error: 'PHONE_EXISTS', message: 'An account with this phone number already exists' });
    }

    const existingEmail = await pool.query('SELECT id FROM users WHERE email = $1', [email]);
    if (existingEmail.rows.length > 0) {
      return res.status(409).json({ error: 'EMAIL_EXISTS', message: 'An account with this email already exists' });
    }

    const password_hash = await bcrypt.hash(password, 10);
    const verificationToken = crypto.randomBytes(32).toString('hex');
    const verificationExpires = new Date(Date.now() + 24 * 60 * 60 * 1000);

    const result = await pool.query(
      `INSERT INTO users (name, phone, email, password_hash, role, is_verified, verification_token, verification_expires)
       VALUES ($1, $2, $3, $4, $5, FALSE, $6, $7)
       RETURNING id, name, phone, email, role, is_verified, created_at`,
      [name, phone, email, password_hash, role || 'resident', verificationToken, verificationExpires]
    );

    const user = result.rows[0];
    try {
      await sendVerificationEmail({ name: user.name, email: user.email, token: verificationToken });
    } catch (emailError) {
      console.error('Failed to send verification email:', emailError.message);
    }

    return res.status(201).json({
      message: 'Account created! Please check your email to verify your account.',
      user: { id: user.id, name: user.name, phone: user.phone, email: user.email, role: user.role, is_verified: false },
      requiresVerification: true,
    });
  } catch (error) {
    console.error('Register error:', error.message);
    return res.status(500).json({ error: 'SERVER_ERROR', message: 'Something went wrong. Please try again.' });
  }
};

// ─────────────────────────────────────────
// VERIFY EMAIL  GET /api/auth/verify-email?token=xxx
// ─────────────────────────────────────────
const verifyEmail = async (req, res) => {
  try {
    const { token } = req.query;
    if (!token) {
      return res.status(400).json({ error: 'MISSING_TOKEN', message: 'Verification token is required' });
    }

    const result = await pool.query(
      `SELECT * FROM users WHERE verification_token = $1 AND verification_expires > NOW()`,
      [token]
    );

    if (result.rows.length === 0) {
      return res.status(400).json({ error: 'INVALID_TOKEN', message: 'Verification link is invalid or has expired.' });
    }

    const user = result.rows[0];
    if (user.is_verified) {
      return res.status(400).json({ error: 'ALREADY_VERIFIED', message: 'This account is already verified.' });
    }

    await pool.query(
      `UPDATE users SET is_verified = TRUE, verification_token = NULL, verification_expires = NULL WHERE id = $1`,
      [user.id]
    );

    try {
      await sendWelcomeEmail({ name: user.name, email: user.email });
    } catch (emailError) {
      console.error('Failed to send welcome email:', emailError.message);
    }

    const jwtToken = jwt.sign({ id: user.id, role: user.role }, process.env.JWT_SECRET, { expiresIn: process.env.JWT_EXPIRES_IN });

    return res.status(200).json({
      message: 'Email verified successfully! Welcome to HydroFlow.',
      user: { id: user.id, name: user.name, phone: user.phone, email: user.email, role: user.role, is_verified: true },
      token: jwtToken,
    });
  } catch (error) {
    console.error('Verify email error:', error.message);
    return res.status(500).json({ error: 'SERVER_ERROR', message: 'Something went wrong. Please try again.' });
  }
};

// ─────────────────────────────────────────
// RESEND VERIFICATION  POST /api/auth/resend-verification
// ─────────────────────────────────────────
const resendVerification = async (req, res) => {
  try {
    const { email } = req.body;
    if (!email) return res.status(400).json({ error: 'MISSING_EMAIL', message: 'Email is required' });

    const result = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'USER_NOT_FOUND', message: 'No account found with this email' });
    }

    const user = result.rows[0];
    if (user.is_verified) {
      return res.status(400).json({ error: 'ALREADY_VERIFIED', message: 'This account is already verified' });
    }

    const verificationToken = crypto.randomBytes(32).toString('hex');
    const verificationExpires = new Date(Date.now() + 24 * 60 * 60 * 1000);

    await pool.query(
      `UPDATE users SET verification_token = $1, verification_expires = $2 WHERE id = $3`,
      [verificationToken, verificationExpires, user.id]
    );

    await sendVerificationEmail({ name: user.name, email: user.email, token: verificationToken });
    return res.status(200).json({ message: 'Verification email resent. Please check your inbox.' });
  } catch (error) {
    console.error('Resend verification error:', error.message);
    return res.status(500).json({ error: 'SERVER_ERROR', message: 'Something went wrong. Please try again.' });
  }
};

// ─────────────────────────────────────────
// LOGIN  POST /api/auth/login
// ─────────────────────────────────────────
const login = async (req, res) => {
  try {
    const { phone, password } = req.body;
    if (!phone || !password) {
      return res.status(400).json({ error: 'MISSING_FIELDS', message: 'Phone and password are required' });
    }

    const result = await pool.query('SELECT * FROM users WHERE phone = $1', [phone]);
    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'INVALID_CREDENTIALS', message: 'Invalid phone number or password' });
    }

    const user = result.rows[0];
    const isPasswordValid = await bcrypt.compare(password, user.password_hash);
    if (!isPasswordValid) {
      return res.status(401).json({ error: 'INVALID_CREDENTIALS', message: 'Invalid phone number or password' });
    }

    if (!user.is_verified) {
      return res.status(403).json({ error: 'EMAIL_NOT_VERIFIED', message: 'Please verify your email before logging in.', email: user.email });
    }

    const token = jwt.sign({ id: user.id, role: user.role }, process.env.JWT_SECRET, { expiresIn: process.env.JWT_EXPIRES_IN });
    return res.status(200).json({
      user: { id: user.id, name: user.name, phone: user.phone, email: user.email, role: user.role },
      token,
    });
  } catch (error) {
    console.error('Login error:', error.message);
    return res.status(500).json({ error: 'SERVER_ERROR', message: 'Something went wrong. Please try again.' });
  }
};

// ─────────────────────────────────────────
// SEND OTP  POST /api/auth/send-otp
// ─────────────────────────────────────────
const sendOtp = async (req, res) => {
  try {
    let { phone, role } = req.body;

    if (!phone) {
      return res.status(400).json({ error: 'MISSING_PHONE', message: 'Phone number is required' });
    }

    // Normalise: strip +254 prefix, keep digits only, expect 9-digit local number
    phone = phone.replace(/^\+254/, '').replace(/\s+/g, '').replace(/[^0-9]/g, '');
    if (phone.startsWith('0')) phone = phone.substring(1); // strip leading 0 if present
    if (phone.length < 9) {
      return res.status(400).json({ error: 'INVALID_PHONE', message: 'Invalid phone number format' });
    }

    const safeRole = ['resident', 'driver'].includes(role) ? role : 'resident';

    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000);

    // Remove any existing OTPs for this phone
    await pool.query('DELETE FROM otp_codes WHERE phone = $1', [phone]);

    await pool.query(
      'INSERT INTO otp_codes (phone, code, role, expires_at) VALUES ($1, $2, $3, $4)',
      [phone, code, safeRole, expiresAt]
    );

    await sendOtpSms(phone, code);

    return res.status(200).json({
      success: true,
      message: 'OTP sent successfully',
      dev: { code }, // Remove in production
    });
  } catch (error) {
    console.error('Send OTP error:', error.message);
    return res.status(500).json({ error: 'SERVER_ERROR', message: 'Something went wrong. Please try again.' });
  }
};

// ─────────────────────────────────────────
// VERIFY OTP  POST /api/auth/verify-otp
// ─────────────────────────────────────────
const verifyOtp = async (req, res) => {
  const client = await pool.connect();
  try {
    let { phone, otp, role: bodyRole } = req.body;

    if (!phone || !otp) {
      return res.status(400).json({ error: 'MISSING_FIELDS', message: 'Phone and OTP are required' });
    }

    // Same normalisation as sendOtp
    phone = phone.replace(/^\+254/, '').replace(/\s+/g, '').replace(/[^0-9]/g, '');
    if (phone.startsWith('0')) phone = phone.substring(1);

    await client.query('BEGIN');

    // Find most-recent non-expired OTP for this phone
    const otpResult = await client.query(
      `SELECT * FROM otp_codes
       WHERE phone = $1 AND expires_at > NOW()
       ORDER BY created_at DESC
       LIMIT 1`,
      [phone]
    );

    if (otpResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(401).json({ error: 'INVALID_OTP', message: 'OTP has expired. Please request a new code.' });
    }

    const otpRecord = otpResult.rows[0];

    if (otpRecord.attempts >= 5) {
      await client.query('DELETE FROM otp_codes WHERE id = $1', [otpRecord.id]);
      await client.query('COMMIT');
      return res.status(429).json({ error: 'TOO_MANY_ATTEMPTS', message: 'Too many failed attempts. Please request a new code.' });
    }

    if (otpRecord.code !== otp) {
      // Increment attempt count
      await client.query('UPDATE otp_codes SET attempts = attempts + 1 WHERE id = $1', [otpRecord.id]);
      await client.query('COMMIT');
      const remaining = 5 - (otpRecord.attempts + 1);
      return res.status(401).json({
        error: 'INVALID_OTP',
        message: remaining > 0 ? `Invalid OTP. ${remaining} attempt${remaining === 1 ? '' : 's'} remaining.` : 'Invalid OTP.',
      });
    }

    // OTP is correct — determine role (from OTP record, fallback to body)
    const role = otpRecord.role || bodyRole || 'resident';

    // Find or create user
    let userResult = await client.query('SELECT * FROM users WHERE phone = $1', [phone]);
    let user;

    if (userResult.rows.length === 0) {
      // New user — create with correct role
      const inserted = await client.query(
        `INSERT INTO users (name, phone, password_hash, role, is_verified)
         VALUES ($1, $2, $3, $4, TRUE)
         RETURNING id, name, phone, email, role`,
        [
          `User ${phone.slice(-4)}`, // temp name; user can update in profile
          phone,
          await bcrypt.hash(crypto.randomBytes(16).toString('hex'), 10),
          role,
        ]
      );
      user = inserted.rows[0];

      // Auto-create driver profile so driver endpoints work immediately
      if (role === 'driver') {
        await client.query(
          `INSERT INTO drivers (user_id, vehicle_plate, status, is_available, is_verified)
           VALUES ($1, 'TBD', 'offline', false, false)
           ON CONFLICT (user_id) DO NOTHING`,
          [user.id]
        );
      }
    } else {
      user = userResult.rows[0];

      // If existing user's role doesn't match requested role, update it
      if (user.role !== role) {
        const updated = await client.query(
          `UPDATE users SET role = $1 WHERE id = $2 RETURNING id, name, phone, email, role`,
          [role, user.id]
        );
        user = updated.rows[0];
      }

      // Ensure driver profile exists for driver users
      if (role === 'driver') {
        await client.query(
          `INSERT INTO drivers (user_id, vehicle_plate, status, is_available, is_verified)
           VALUES ($1, 'TBD', 'offline', false, false)
           ON CONFLICT (user_id) DO NOTHING`,
          [user.id]
        );
      }
    }

    // Delete used OTP
    await client.query('DELETE FROM otp_codes WHERE id = $1', [otpRecord.id]);
    await client.query('COMMIT');

    const token = jwt.sign(
      { id: user.id, role: user.role },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN }
    );

    return res.status(200).json({
      success: true,
      message: 'OTP verified successfully',
      token,
      user: {
        id: user.id,
        name: user.name,
        phone: user.phone,
        email: user.email || null,
        role: user.role,
      },
    });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Verify OTP error:', error.message);
    return res.status(500).json({ error: 'SERVER_ERROR', message: 'Something went wrong. Please try again.' });
  } finally {
    client.release();
  }
};

// alias for spec compliance: POST /api/auth/request-otp == POST /api/auth/send-otp
const requestOtp = sendOtp;

// GET /api/auth/profile
const getProfile = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT id, name, phone, email, role, is_verified, created_at FROM users WHERE id = $1`,
      [req.user.id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'NOT_FOUND', message: 'User not found' });
    }
    return res.status(200).json({ user: result.rows[0] });
  } catch (error) {
    console.error('Get profile error:', error.message);
    return res.status(500).json({ error: 'SERVER_ERROR', message: 'Something went wrong.' });
  }
};

module.exports = { register, login, verifyEmail, resendVerification, sendOtp, verifyOtp, requestOtp, getProfile };
