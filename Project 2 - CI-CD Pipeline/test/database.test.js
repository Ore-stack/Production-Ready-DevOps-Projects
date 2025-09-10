const { spawn } = require('child_process');

describe('Database Integration', () => {
  /**
   * Test database availability when DATABASE_URL is provided
   */
  describe('Database Connection', () => {
    it('should connect to database when DATABASE_URL is available', async () => {
      const databaseUrl = process.env.DATABASE_URL;
      
      if (!databaseUrl) {
        console.log('⚠️  DATABASE_URL not provided, skipping database tests');
        return;
      }

      // Test database connection using pg_isready
      const isPostgres = databaseUrl.includes('postgres://');
      
      if (isPostgres) {
        // Extract connection details for pg_isready
        const url = new URL(databaseUrl);
        
        return new Promise((resolve, reject) => {
          const pgIsReady = spawn('pg_isready', [
            '-h', url.hostname,
            '-p', url.port || '5432',
            '-U', url.username
          ], {
            env: { ...process.env, PGPASSWORD: url.password }
          });

          let output = '';
          pgIsReady.stdout.on('data', (data) => {
            output += data.toString();
          });

          pgIsReady.stderr.on('data', (data) => {
            output += data.toString();
          });

          pgIsReady.on('close', (code) => {
            if (code === 0) {
              console.log('✅ Database connection successful');
              resolve();
            } else {
              console.log('❌ Database connection failed:', output);
              reject(new Error(`Database connection failed with code ${code}`));
            }
          });

          // Timeout after 10 seconds
          setTimeout(() => {
            pgIsReady.kill();
            reject(new Error('Database connection timeout'));
          }, 10000);
        });
      } else {
        console.log('⚠️  Non-PostgreSQL database detected, skipping connection test');
      }
    });

    it('should have app_status table available when database is connected', async () => {
      const databaseUrl = process.env.DATABASE_URL;
      
      if (!databaseUrl || !databaseUrl.includes('postgres://')) {
        console.log('⚠️  PostgreSQL DATABASE_URL not available, skipping table test');
        return;
      }

      // Test table existence using psql
      const url = new URL(databaseUrl);
      
      return new Promise((resolve, reject) => {
        const psql = spawn('psql', [
          `-h${url.hostname}`,
          `-p${url.port || '5432'}`,
          `-U${url.username}`,
          `-d${url.pathname.slice(1)}`,
          '-c', 'SELECT COUNT(*) FROM app_status;'
        ], {
          env: { ...process.env, PGPASSWORD: url.password }
        });

        let output = '';
        psql.stdout.on('data', (data) => {
          output += data.toString();
        });

        psql.stderr.on('data', (data) => {
          output += data.toString();
        });

        psql.on('close', (code) => {
          if (code === 0 && output.includes('(1 row)')) {
            console.log('✅ app_status table is accessible');
            resolve();
          } else {
            console.log('❌ app_status table test failed:', output);
            reject(new Error(`Table test failed with code ${code}`));
          }
        });

        // Timeout after 10 seconds
        setTimeout(() => {
          psql.kill();
          reject(new Error('Table test timeout'));
        }, 10000);
      });
    });
  });
});