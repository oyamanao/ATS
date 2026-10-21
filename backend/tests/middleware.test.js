const { verifySession } = require('../src/middleware/verifySession');
const { attendanceLimiter } = require('../src/middleware/rateLimiter');
const { supabase } = require('../src/config/supabase');

describe('Middleware Tests', () => {
  describe('verifySession', () => {
    let req, res, next;

    beforeEach(() => {
      req = { headers: {} };
      res = {
        status: jest.fn().mockReturnThis(),
        json: jest.fn().mockReturnThis(),
      };
      next = jest.fn();
      jest.clearAllMocks();
    });

    it('should return 401 when Authorization header is missing', async () => {
      await verifySession(req, res, next);
      expect(res.status).toHaveBeenCalledWith(401);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ error: expect.stringContaining('token missing') })
      );
      expect(next).not.toHaveBeenCalled();
    });

    it('should return 401 when Authorization header does not start with Bearer', async () => {
      req.headers.authorization = 'Basic 123456';
      await verifySession(req, res, next);
      expect(res.status).toHaveBeenCalledWith(401);
      expect(next).not.toHaveBeenCalled();
    });

    it('should return 401 when supabase returns auth error', async () => {
      req.headers.authorization = 'Bearer test_token';
      jest.spyOn(supabase.auth, 'getUser').mockResolvedValueOnce({
        data: { user: null },
        error: new Error('Invalid JWT'),
      });

      await verifySession(req, res, next);
      expect(res.status).toHaveBeenCalledWith(401);
      expect(res.json).toHaveBeenCalledWith({ error: 'Invalid or expired session' });
      expect(next).not.toHaveBeenCalled();
    });

    it('should return 403 when email does not belong to @iiitdwd.ac.in', async () => {
      req.headers.authorization = 'Bearer test_token';
      jest.spyOn(supabase.auth, 'getUser').mockResolvedValueOnce({
        data: {
          user: {
            id: 'u-123',
            email: 'outsider@gmail.com',
          },
        },
        error: null,
      });

      await verifySession(req, res, next);
      expect(res.status).toHaveBeenCalledWith(403);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ error: expect.stringContaining('university accounts') })
      );
      expect(next).not.toHaveBeenCalled();
    });

    it('should call next and attach user when email is verified institutional domain', async () => {
      req.headers.authorization = 'Bearer test_token';
      const mockUser = {
        id: 'u-123',
        email: '21bcs001@iiitdwd.ac.in',
      };
      jest.spyOn(supabase.auth, 'getUser').mockResolvedValueOnce({
        data: { user: mockUser },
        error: null,
      });

      await verifySession(req, res, next);
      expect(next).toHaveBeenCalled();
      expect(req.user).toEqual(mockUser);
    });

    it('should return 500 when auth throws unexpected exception', async () => {
      req.headers.authorization = 'Bearer test_token';
      jest.spyOn(supabase.auth, 'getUser').mockRejectedValueOnce(new Error('Network failure'));

      await verifySession(req, res, next);
      expect(res.status).toHaveBeenCalledWith(500);
      expect(res.json).toHaveBeenCalledWith({ error: 'Authentication service unavailable' });
    });
  });

  describe('rateLimiter', () => {
    it('should export rate limiter middleware', () => {
      expect(typeof attendanceLimiter).toBe('function');
    });
  });
});
