const nodemailer = require('nodemailer');

// ─────────────────────────────────────────
// EMAIL SERVICE
// Handles sending emails via Gmail
// ─────────────────────────────────────────

// Create transporter
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.GMAIL_USER,
    pass: process.env.GMAIL_APP_PASSWORD,
  },
});

// ─────────────────────────────────────────
// SEND VERIFICATION EMAIL
// ─────────────────────────────────────────
const sendVerificationEmail = async ({ name, email, token }) => {
  const verificationUrl = `${process.env.FRONTEND_URL}/verify-email?token=${token}`;

  const mailOptions = {
    from: `"HydroFlow 💧" <${process.env.GMAIL_USER}>`,
    to: email,
    subject: 'Verify your HydroFlow account',
    html: `
      <!DOCTYPE html>
      <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
        </head>
        <body style="margin:0; padding:0; background:#F8FAFC; font-family: 'Segoe UI', Arial, sans-serif;">
          
          <div style="max-width:560px; margin:40px auto; background:#FFFFFF; border-radius:16px; overflow:hidden; box-shadow: 0 4px 24px rgba(59,130,246,0.08);">
            
            <!-- Header -->
            <div style="background: linear-gradient(135deg, #0A1628 0%, #1E3A5F 100%); padding: 40px 40px 32px; text-align:center;">
              <div style="display:inline-block; background:#1E3A5F; border-radius:16px; padding:16px; margin-bottom:16px;">
                <span style="font-size:32px;">💧</span>
              </div>
              <h1 style="margin:0; color:#FFFFFF; font-size:24px; font-weight:800; letter-spacing:0.5px;">HydroFlow</h1>
              <p style="margin:8px 0 0; color:rgba(255,255,255,0.5); font-size:13px;">Smart Water Delivery System</p>
            </div>

            <!-- Body -->
            <div style="padding:40px;">
              <h2 style="margin:0 0 8px; color:#1E293B; font-size:20px; font-weight:700;">
                Welcome, ${name}! 👋
              </h2>
              <p style="margin:0 0 24px; color:#64748B; font-size:14px; line-height:1.6;">
                Thank you for creating an HydroFlow account. Please verify your email address to activate your account and start monitoring your water tank.
              </p>

              <!-- Button -->
              <div style="text-align:center; margin:32px 0;">
                <a href="${verificationUrl}" 
                   style="display:inline-block; background:#3B82F6; color:#FFFFFF; text-decoration:none; padding:14px 40px; border-radius:10px; font-size:15px; font-weight:700; letter-spacing:0.3px;">
                  Verify My Account
                </a>
              </div>

              <p style="margin:24px 0 0; color:#94A3B8; font-size:12px; text-align:center; line-height:1.6;">
                This link expires in <strong>24 hours</strong>.<br>
                If you did not create this account, you can safely ignore this email.
              </p>

              <!-- Divider -->
              <hr style="margin:32px 0; border:none; border-top:1px solid #E2E8F0;">

              <!-- Link fallback -->
              <p style="margin:0; color:#94A3B8; font-size:11px; line-height:1.6;">
                If the button does not work, copy and paste this link into your browser:<br>
                <a href="${verificationUrl}" style="color:#3B82F6; word-break:break-all;">${verificationUrl}</a>
              </p>
            </div>

            <!-- Footer -->
            <div style="background:#F8FAFC; padding:20px 40px; text-align:center; border-top:1px solid #E2E8F0;">
              <p style="margin:0; color:#94A3B8; font-size:12px;">
                💧 HydroFlow — Juja, Kenya
              </p>
            </div>

          </div>

        </body>
      </html>
    `,
  };

  await transporter.sendMail(mailOptions);
  console.log(`✅ Verification email sent to ${email}`);
};

// ─────────────────────────────────────────
// SEND WELCOME EMAIL
// Sent after successful verification
// ─────────────────────────────────────────
const sendWelcomeEmail = async ({ name, email }) => {
  const mailOptions = {
    from: `"HydroFlow 💧" <${process.env.GMAIL_USER}>`,
    to: email,
    subject: 'Welcome to HydroFlow! 💧',
    html: `
      <!DOCTYPE html>
      <html>
        <body style="margin:0; padding:0; background:#F8FAFC; font-family: 'Segoe UI', Arial, sans-serif;">
          
          <div style="max-width:560px; margin:40px auto; background:#FFFFFF; border-radius:16px; overflow:hidden; box-shadow: 0 4px 24px rgba(59,130,246,0.08);">
            
            <!-- Header -->
            <div style="background: linear-gradient(135deg, #0A1628 0%, #1E3A5F 100%); padding:40px; text-align:center;">
              <span style="font-size:48px;">💧</span>
              <h1 style="margin:16px 0 0; color:#FFFFFF; font-size:24px; font-weight:800;">You're verified!</h1>
            </div>

            <!-- Body -->
            <div style="padding:40px;">
              <h2 style="margin:0 0 8px; color:#1E293B; font-size:20px;">
                Welcome aboard, ${name}! 🎉
              </h2>
              <p style="margin:0 0 16px; color:#64748B; font-size:14px; line-height:1.6;">
                Your HydroFlow account is now active. Here is what you can do:
              </p>

              <div style="background:#F8FAFC; border-radius:10px; padding:20px; margin:20px 0;">
                <p style="margin:0 0 10px; color:#1E293B; font-size:13px;">✅ Monitor your water tank level in real time</p>
                <p style="margin:0 0 10px; color:#1E293B; font-size:13px;">🔮 Get predictions on when your tank will run out</p>
                <p style="margin:0 0 10px; color:#1E293B; font-size:13px;">🔍 Detect leaks automatically at night</p>
                <p style="margin:0; color:#1E293B; font-size:13px;">🏍️ Order water with M-Pesa payment</p>
              </div>

              <p style="margin:0; color:#64748B; font-size:14px; line-height:1.6;">
                Open the <strong>HydroFlow mobile app</strong> and sign in to get started.
              </p>
            </div>

            <!-- Footer -->
            <div style="background:#F8FAFC; padding:20px 40px; text-align:center; border-top:1px solid #E2E8F0;">
              <p style="margin:0; color:#94A3B8; font-size:12px;">💧 HydroFlow — Juja, Kenya</p>
            </div>

          </div>

        </body>
      </html>
    `,
  };

  await transporter.sendMail(mailOptions);
  console.log(`✅ Welcome email sent to ${email}`);
};

module.exports = { sendVerificationEmail, sendWelcomeEmail };