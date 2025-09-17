const express = require('express');
const os = require('os');
const { Pool } = require('pg');

const app = express();
const ENVIRONMENT = process.env.ENVIRONMENT || 'development';
const DATABASE_URL = process.env.DATABASE_URL;

// Initialize PostgreSQL connection pool
const pool = new Pool({
  connectionString: DATABASE_URL,
  ssl: ENVIRONMENT === 'production' ? { rejectUnauthorized: false } : false,
});

// Test DB connection on startup
pool.connect()
  .then(client => {
    return client.query('SELECT NOW()')
      .then(res => {
        console.log(`🗄️ Connected to database`);
        console.log(`🕒 DB Time: ${res.rows[0].now}`);
        client.release();
      })
      .catch(err => {
        client.release();
        console.error('❌ Error executing test query:', err.stack);
      });
  })
  .catch(err => {
    console.error('❌ Failed to connect to database:', err.stack);
  });

// Middleware
app.use(express.json());
app.use(express.static('public'));

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
            <li><a href="/db-check">Database Check</a></li>
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

// API info endpoint
app.get('/api/info', (req, res) => {
  res.json({
    app: 'my-aws-webapp',
    version: '1.0.0',
    environment: ENVIRONMENT,
    timestamp: new Date().toISOString(),
    nodeVersion: process.version,
  });
});

// System info endpoint
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

// Database check endpoint
app.get('/db-check', async (req, res) => {
  try {
    const result = await pool.query('SELECT NOW()');
    res.json({ status: 'connected', dbTime: result.rows[0].now });
  } catch (error) {
    console.error('DB check failed:', error);
    res.status(500).json({ status: 'error', message: error.message });
  }
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: 'Endpoint not found',
    path: req.path,
    availableEndpoints: ['/', '/health', '/api/info', '/api/system', '/db-check'],
  });
});

// Error handler
app.use((error, req, res, next) => {
  console.error('Unhandled error:', error);
  res.status(500).json({
    error: 'Internal server error',
    message: ENVIRONMENT === 'production' ? 'Something went wrong' : error.message,
  });
});

module.exports = app;
