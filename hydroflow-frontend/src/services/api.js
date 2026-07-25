import axios from 'axios';

const BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:3000/api';

const api = axios.create({
  baseURL: BASE_URL,
  headers: { 'Content-Type': 'application/json' },
});

api.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('hydroflow_token');
    if (token) config.headers.Authorization = `Bearer ${token}`;
    return config;
  },
  (error) => Promise.reject(error)
);

api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      localStorage.removeItem('hydroflow_token');
      localStorage.removeItem('hydroflow_user');
      window.location.href = '/login';
    }
    return Promise.reject(error);
  }
);

export const authAPI = {
  register: (data) => api.post('/auth/register', data),
  login: (data) => api.post('/auth/login', data),
  verifyEmail: (token) => api.get(`/auth/verify-email?token=${token}`),
  resendVerification: (email) => api.post('/auth/resend-verification', { email }),
};

export const userAPI = {
  getAll: () => api.get('/users'),
  getMe: () => api.get('/users/me'),
};

export const productAPI = {
  getAll: () => api.get('/products'),
  create: (data) => api.post('/products', data),
  update: (id, data) => api.put(`/products/${id}`, data),
};

export const driverAPI = {
  register:          (data)           => api.post('/drivers/register', data),
  updateLocation:    (data)           => api.put('/drivers/location', data),
  toggleAvailability:(data)           => api.put('/drivers/availability', data),
  updateStatusSelf:  (status)         => api.patch('/drivers/status', { status }),
  getNearby:         (lat, lng)       => api.get(`/drivers/nearby?lat=${lat}&lng=${lng}`),
  // admin
  getAllAdmin:        (params = {})    => api.get('/drivers/admin/all', { params }),
  getLocations:      ()               => api.get('/drivers/admin/locations'),
  getDetailAdmin:    (id)             => api.get(`/drivers/admin/${id}`),
  updateStatusAdmin: (id, status)     => api.patch(`/drivers/admin/${id}/status`, { status }),
  reassignAdmin:     (id, body)       => api.patch(`/drivers/admin/${id}/reassign`, body),
  verify:            (id, is_verified)=> api.put(`/drivers/${id}/verify`, { is_verified }),
};

export const orderAPI = {
  create: (data) => api.post('/orders', data),
  getAll: () => api.get('/orders'),
  getDriverOrders: () => api.get('/orders/driver'),
  getAllAdmin: () => api.get('/orders/admin/all'),
  getById: (id) => api.get(`/orders/${id}`),
  updateStatus: (id, status) => api.put(`/orders/${id}/status`, { status }),
  assignDriver: (id, driver_id) => api.put(`/orders/${id}/assign`, { driver_id }),
  rate: (id, rating) => api.post(`/orders/${id}/rate`, { rating }),
  cancel: (id) => api.delete(`/orders/${id}`),
};

export const qualityAPI = {
  verify: (orderId) => api.post(`/quality/orders/${orderId}/verify`),
  getReport: (orderId) => api.get(`/quality/orders/${orderId}/report`),
};

export default api;
