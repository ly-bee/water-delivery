require('dotenv').config();
const AfricasTalking = require('africastalking');

const AT = AfricasTalking({
  apiKey: process.env.AT_API_KEY,
  username: process.env.AT_USERNAME,
});

const sms = AT.SMS;

const formatPhone = (phone) =>
  phone.startsWith('+') ? phone : `+254${phone.substring(1)}`;

const sendSMS = async (phone, message) => {
  try {
    const result = await sms.send({
      to: [formatPhone(phone)],
      message,
      from: process.env.AT_SENDER_ID || undefined,
    });
    console.log(`📱 SMS sent to ${formatPhone(phone)}`);
    return { success: true, result };
  } catch (error) {
    console.error('SMS send error:', error.message);
    return { success: false, error: error.message };
  }
};

// Send order status update SMS to customer
const sendOrderStatusSMS = async ({ customerPhone, customerName, status, volumeLiters, driverName }) => {
  const messages = {
    ASSIGNED: `HydroFlow: Hi ${customerName}, your order of ${volumeLiters}L water has been assigned to driver ${driverName}. They are on their way soon.`,
    IN_TRANSIT: `HydroFlow: Hi ${customerName}, your water delivery (${volumeLiters}L) is now on the way. Driver: ${driverName}.`,
    DELIVERED: `HydroFlow: Hi ${customerName}, your ${volumeLiters}L water delivery has been completed. Please rate your experience on the app.`,
    CANCELLED: `HydroFlow: Hi ${customerName}, your water order of ${volumeLiters}L has been cancelled. Contact support if this was an error.`,
  };

  const message = messages[status];
  if (!message) return { success: false, error: 'No SMS template for this status' };

  return sendSMS(customerPhone, message);
};

module.exports = { sendSMS, sendOrderStatusSMS };
