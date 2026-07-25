const jwt = require('jsonwebtoken');

const protect = (req, res, next) => {
    try {
        const authHeader = req.headers.authorization;

        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return res.status(401).json({
                error: 'NO_TOKEN',
                message: 'Access denied. No token provided.'
            });
        }

        // Extract the token after "Bearer "
        const token = authHeader.split(' ')[1];

        // Verify the token using jwt_secret
        const decoded = jwt.verify(token, process.env.JWT_SECRET);

        req.user = decoded;

        next();

    } catch (error) {
        return res.status(401).json({
            error: 'INVALID_TOKEN',
            message: 'Your session has expired. Please log in again.'
        });
    }
};

// Restrict To Role Middleware
const restrictTo = (...roles) => {
    return (req, res, next) => {
        if (!roles.includes(req.user.role)) {
            return res.status(403).json({
                error: 'FORBIDDEN',
                message: 'You do not have permission to perform this action.'
            });
        }
        next();
    };
};

module.exports = { protect, restrictTo };