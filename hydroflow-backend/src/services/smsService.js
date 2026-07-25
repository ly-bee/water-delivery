const AfricasTalking = require('africastalking');

let _sms = null;

const getSms = () => {
  if (!_sms) {
    const at = AfricasTalking({
      apiKey: process.env.AT_API_KEY || 'dummy_key',
      username: process.env.AT_USERNAME || 'sandbox',
    });
    _sms = at.SMS;
  }
  return _sms;
};

const formatPhone = (phone) => {
  const cleaned = phone.replace(/\s+/g, '').replace(/[^0-9+]/g, '');
  if (cleaned.startsWith('+254')) return cleaned;
  if (cleaned.startsWith('0')) return `+254${cleaned.slice(1)}`;
  if (cleaned.length === 9) return `+254${cleaned}`;
  return cleaned;
};

/**
 * Sends an OTP SMS via Africa's Talking.
 * Falls back gracefully in dev/missing-config scenarios.
 */
const sendOtpSms = async (phone, code) => {
  const formattedPhone = formatPhone(phone);
  const message = `Your HydroFlow verification code is ${code}. Valid for 10 minutes. Do not share this code.`;

  // Always log in dev so the OTP is visible without a real phone
  console.log(`[OTP] ${formattedPhone}: ${code}`);

  try {
    const result = await getSms().send({
      to: [formattedPhone],
      message,
      from: process.env.AT_SENDER_ID || 'HydroFlow',
    });
    return { sent: true, result };
  } catch (err) {
    // In sandbox, AT may reject due to config; never crash the OTP flow
    console.warn('[SMS] Africa\'s Talking send failed (non-fatal):', err.message);
    return { sent: false, error: err.message };
  }
};

module.exports = { sendOtpSms, formatPhone };
