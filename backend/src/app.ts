import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import rateLimit from 'express-rate-limit';
import { errorHandler } from './middleware/errorHandler';
import { sendSuccess } from './utils/response';

const app = express();

// --------------- Security Middleware ---------------
app.use(helmet());
app.use(cors());

// --------------- Rate Limiting ---------------
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per window
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, error: { code: 'RATE_LIMIT', message: 'Too many requests, please try again later' } },
});
app.use(limiter);

// --------------- Body Parsing ---------------
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// --------------- Request Logging ---------------
app.use(morgan('dev'));

// --------------- Health Check ---------------
app.get('/api/health', (_req, res) => {
  sendSuccess(res, { message: 'AgriConnect API is running' });
});

// --------------- Global Error Handler (must be last) ---------------
app.use(errorHandler);

export default app;
