const os = require('os');
const app = require('./app.js');

const PORT = process.env.PORT || 3001;
const ENVIRONMENT = process.env.ENVIRONMENT || 'development';

const server = app.listen(PORT, () => {
  console.log(`
  🚀 App running on port ${PORT}
  🌍 Environment: ${ENVIRONMENT}
  📦 Node version: ${process.version}
  🖥️  Hostname: ${os.hostname()}
  📊 Available endpoints:
     - http://0.0.0.0:${PORT}/
     - http://0.0.0.0:${PORT}/health
     - http://0.0.0.0:${PORT}/api/info
     - http://0.0.0.0:${PORT}/api/system
  `);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  server.close(() => process.exit(0));
});

process.on('SIGINT', () => {
  console.log('SIGINT received, shutting down gracefully');
  server.close(() => process.exit(0));
});

// Catches any hidden

process.on('uncaughtException', (err) => {
  console.error('Uncaught Exception:', err);
});
