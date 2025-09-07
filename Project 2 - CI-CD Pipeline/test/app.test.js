const request = require('supertest');
const app = require('../app'); // Import your Express app

describe('Express App Endpoints', () => {
  /**
   * Root endpoint test
   */
  describe('GET /', () => {
    it('should return 200 and contain expected HTML content', async () => {
      const response = await request(app).get('/');

      // Assert status
      expect(response.status).toBe(200);

      // Assert response type
      expect(response.headers['content-type']).toMatch(/html/);

      // Assert body content
      expect(response.text).toContain('My AWS DevOps Web App');
    });
  });

  /**
   * Health check endpoint test
   */
  describe('GET /health', () => {
    it('should return 200 and a healthy status JSON', async () => {
      const response = await request(app).get('/health');

      // Assert status
      expect(response.status).toBe(200);

      // Assert response type
      expect(response.headers['content-type']).toMatch(/json/);

      // Assert body payload
      expect(response.body).toEqual(
        expect.objectContaining({
          status: 'healthy',
        })
      );
    });
  });
});