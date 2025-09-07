const express = require('express');
const os = require('os');

const app = express();
// const PORT = process.env.PORT || 3001;
const ENVIRONMENT = process.env.ENVIRONMENT || 'development';

// Middleware
app.use(express.json());
app.use(express.static('public')); // Serve static files if needed

// Request logging middleware
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`);
  next();
});

// Simple home page
app.get('/', (req, res) => {
  try {
    res.send(`
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>🚀 My AWS DevOps Web App</title>
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; margin: 0; padding: 20px; background-color: #f4f4f4; color: #333; }
          .container { max-width: 800px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
          h1 { color: #2c3e50; }
          .info-box { background: #f8f9fa; border-left: 4px solid #3498db; padding: 15px; margin: 20px 0; }
        </style>
      </head>
      <body>
        <div class="container">
          <h1>🚀 My AWS DevOps Web App</h1>
          <p>This app was deployed automatically to AWS ECS!</p>
          
          <div class="info-box">
            <p><strong>Environment:</strong> ${ENVIRONMENT}</p>
            <p><strong>Current time:</strong> ${new Date().toLocaleString()}</p>
            <p><strong>Container ID:</strong> ${os.hostname()}</p>
            <p><strong>Server uptime:</strong> ${Math.floor(process.uptime())} seconds</p>
            <p><strong>Platform:</strong> ${process.platform} ${process.arch}</p>
          </div>
          
          <h2>Endpoints:</h2>
          <ul>
            <li><a href="/health">Health Check</a></li>
            <li><a href="/api/info">API Info</a></li>
            <li><a href="/api/system">System Info</a></li>
          </ul>
        </div>
      </body>
      </html>
    `);
  } catch (error) {
    console.error('Error rendering homepage:', error);
    res.status(500).send('Internal Server Error');
  }
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    environment: ENVIRONMENT,
    uptime: process.uptime(),
  });
});

// Simple API endpoint
app.get('/api/info', (req, res) => {
  res.json({
    app: 'my-aws-webapp',
    version: '1.0.0',
    environment: ENVIRONMENT,
    timestamp: new Date().toISOString(),
    nodeVersion: process.version,
  });
});

// System information endpoint
app.get('/api/system', (req, res) => {
  res.json({
    hostname: os.hostname(),
    platform: os.platform(),
    architecture: os.arch(),
    totalMemory: os.totalmem(),
    freeMemory: os.freemem(),
    cpus: os.cpus().length,
    uptime: os.uptime(),
    loadavg: os.loadavg(),
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: 'Endpoint not found',
    path: req.path,
    availableEndpoints: ['/', '/health', '/api/info', '/api/system'],
  });
});

// Error handler
app.use((error, req, res, next) => { // eslint-disable-line no-unused-vars
  console.error('Unhandled error:', error);
  res.status(500).json({
    error: 'Internal server error',
    message: ENVIRONMENT === 'production' ? 'Something went wrong' : error.message,
  });
});

module.exports = app;
