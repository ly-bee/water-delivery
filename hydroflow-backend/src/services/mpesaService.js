const axios = require('axios');

const MPESA_BASE_URL = 'https://sandbox.safaricom.co.ke';

// Generate the access token
const getAccessToken = async () => {
    const { MPESA_CONSUMER_KEY, MPESA_CONSUMER_SECRET } = process.env;

    const ccredentials = Buffer.from(
        `${MPESA_CONSUMER_KEY}:${MPESA_CONSUMER_SECRET}`
    ).toString('base64');

    const response = await axios.get(
        `${MPESA_BASE_URL}/oauth/v1/generate?grant_type=client_credentials`,
        {
            headers: {
                Authorization: `Basic ${ccredentials}`,
            },
        }
    );

    return response.data.access_token;
};

// Generate Password
const generatePassword = (timestamp) => {
    const { MPESA_SHORTCODE, MPESA_PASSKEY } = process.env;
    const raw = `${MPESA_SHORTCODE}${MPESA_PASSKEY}${timestamp}`;
    return Buffer.from(raw).toString('base64');
};

// Format timestamp
const getTimestamp = () => {
  const now = new Date(Date.now());
  const pad = (n) => String(n).padStart(2, '0');
  const year = now.getFullYear();
  const month = pad(now.getMonth() + 1);
  const day = pad(now.getDate());
  const hours = pad(now.getHours());
  const minutes = pad(now.getMinutes());
  const seconds = pad(now.getSeconds());
  return `${year}${month}${day}${hours}${minutes}${seconds}`;
};

// Format phone number
const formatPhone = (phone) => {
    const cleaned = phone.replace(/\s+/g, '');
    if (cleaned.startsWith('0')) {
        return `254${cleaned.slice(1)}`;
    }
    if (cleaned.startsWith('+254')) {
        return cleaned.slice(1);
    }
    return cleaned;
};

// Initiate STK Push
const initiateSTKPush = async ({ phone, amount, orderId, productName }) => {
    const token = await getAccessToken();
    const timestamp = getTimestamp();
    const password = generatePassword(timestamp);

    const { MPESA_SHORTCODE, MPESA_CALLBACK_URL } = process.env;

    const payload = {
        BusinessShortCode: MPESA_SHORTCODE,
        Password: password,
        Timestamp: timestamp,
        TransactionType: 'CustomerPayBillOnline',
        Amount: amount,
        PartyA: formatPhone(phone),
        PartyB: MPESA_SHORTCODE,
        PhoneNumber: formatPhone(phone),
        CallBackURL: MPESA_CALLBACK_URL,
        AccountReference: `hydroflow-${orderId}`,
        TransactionDesc: `Payment for ${productName || 'water delivery'}`,
    };

    const response = await axios.post(
        `${MPESA_BASE_URL}/mpesa/stkpush/v1/processrequest`,
        payload,
        {
            headers: {
                Authorization: `Bearer ${token}`,
                'Content-Type': 'application/json',
            },
        }
    );

    return response.data;
};

module.exports = { initiateSTKPush, formatPhone };