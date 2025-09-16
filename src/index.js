import { SamsungLogisticsMcpServer } from './server.js';
import { createLogger } from './utils/logger.js';

const bootstrapLogger = createLogger('BOOT');

const server = new SamsungLogisticsMcpServer();
server
  .run()
  .then(() => {
    bootstrapLogger.info('Server startup complete');
  })
  .catch((error) => {
    bootstrapLogger.error(`Startup failed: ${error?.message ?? error}`);
    process.exit(1);
  });
