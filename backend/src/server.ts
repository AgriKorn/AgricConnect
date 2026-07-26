import app from './app';
import { env } from './config/env';
import logger from './utils/logger';
import { seedDevAdmin } from './modules/user/seedAdmin';

const PORT = env.PORT;

const start = async () => {
  if (env.NODE_ENV !== 'production') {
    await seedDevAdmin();
  }

  app.listen(PORT, () => {
    logger.info(`🚀 AgriConnect API running on port ${PORT}`);
    logger.info(`📋 Environment: ${env.NODE_ENV}`);
    logger.info(`💚 Health check: http://localhost:${PORT}/api/health`);
  });
};

start();
