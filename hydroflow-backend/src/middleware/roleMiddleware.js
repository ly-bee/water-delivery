const allowRoles = (...roles) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({
        error: 'UNAUTHORIZED',
        message: 'You must be logged in.',
      });
    }

    if (!roles.includes(req.user.role)) {
      return res.status(403).json({
        error: 'FORBIDDEN',
        message: `Access denied. Required role: ${roles.join(' or ')}.`,
      });
    }

    next();
  };
};

// Block residents from React dashboard
const blockResidents = (req, res, next) => {
  if (!req.user) {
    return res.status(401).json({
      error: 'UNAUTHORIZED',
      message: 'You must be logged in.',
    });
  }

  if (req.user.role === 'resident') {
    return res.status(403).json({
      error: 'FORBIDDEN',
      message: 'Residents must use the HydroFlow mobile app.',
    });
  }

  next();
};

module.exports = { allowRoles, blockResidents };