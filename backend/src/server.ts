import app from './app';
import { env } from './config/env';
import logger from './utils/logger';

const PORT = parseInt(env.PORT, 10);

app.listen(PORT, () => {
  logger.info(`🚀 AgriConnect API running on port ${PORT}`);
  logger.info(`📋 Environment: ${env.NODE_ENV}`);
  logger.info(`💚 Health check: http://localhost:${PORT}/api/health`);
});
