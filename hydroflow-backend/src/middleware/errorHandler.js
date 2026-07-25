// Global Error Handler
const errorHandler = (err, req, res, next) => {
    // Log the full error for debugging
    console.error('Unhandled error:', err.stack);

    // Send a clean response to the client
    return res.status(500).json({
        error: 'SERVER_ERROR',
        message: 'An unexpected error occurred. PLease try again.'
    });
};

module.exports = { errorHandler };