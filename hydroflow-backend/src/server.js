require('dotenv').config();
const http    = require('http');
const express = require('express');
const cors    = require('cors');
const jwt     = require('jsonwebtoken');
const { Server } = require('socket.io');
const { connectPostgres } = require('./config/db');
const { setIo }           = require('./config/socket');

const authRoutes         = require('./routes/auth.routes');
const userRoutes         = require('./routes/user.routes');
const driverRoutes       = require('./routes/driver.routes');
const driverSelfRoutes   = require('./routes/driver.self.routes');
const orderRoutes        = require('./routes/order.routes');
const productRoutes      = require('./routes/product.routes');
const qualityRoutes      = require('./routes/quality.routes');
const notificationRoutes = require('./routes/notification.routes');
const mpesaRoutes        = require('./routes/mpesa.routes');
const paymentsRoutes     = require('./routes/payments.routes');
const adminRoutes        = require('./routes/admin.routes');

const { errorHandler } = require('./middleware/errorHandler');

const app    = express();
const server = http.createServer(app);

const io = new Server(server, {
  cors: { origin: '*', methods: ['GET', 'POST'] },
  pingTimeout: 60000,
});

// Only admins can connect to the socket — they join 'admin-room'
io.use((socket, next) => {
  const token = socket.handshake.auth?.token;
  if (!token) return next(new Error('No token'));
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    if (decoded.role !== 'admin') return next(new Error('Forbidden'));
    socket.adminId = decoded.id;
    next();
  } catch {
    next(new Error('Invalid token'));
  }
});

io.on('connection', (socket) => {
  socket.join('admin-room');
  socket.on('disconnect', () => {});
});

setIo(io);

app.use(cors());
app.use(express.json());

app.get('/api/health', (req, res) =>
  res.json({ status: 'ok', message: 'HydroFlow server is running', timestamp: new Date().toISOString() })
);

app.use('/api/auth',          authRoutes);
app.use('/api/users',         userRoutes);
app.use('/api/drivers',       driverRoutes);
app.use('/api/driver',        driverSelfRoutes);
app.use('/api/orders',        orderRoutes);
app.use('/api/products',      productRoutes);
app.use('/api/quality',       qualityRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/mpesa',         mpesaRoutes);
app.use('/api/payments',      paymentsRoutes);
app.use('/api/admin',         adminRoutes);

app.use(errorHandler);

const PORT = process.env.PORT || 3000;

const startServer = async () => {
  await connectPostgres();
  server.listen(PORT, () => {
    console.log(`HydroFlow server running on port ${PORT}`);
  });
};

startServer();
