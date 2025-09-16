import { createServer } from 'node:http';
import { HTTP_CONFIG, SERVER_METADATA } from '../config/constants.js';
import { nowUtc } from '../utils/time.js';

/**
 * HTTP 서버를 생성합니다. (Creates the HTTP server.)
 */
export const createHttpServer = (logger) => {
  const server = createServer((req, res) => {
    const url = new URL(req.url, `http://${req.headers.host}`);

    Object.entries(HTTP_CONFIG.cors).forEach(([key, value]) => {
      res.setHeader(key, value);
    });

    if (req.method === 'OPTIONS') {
      res.writeHead(200);
      res.end();
      return;
    }

    if (url.pathname === '/healthz') {
      const payload = {
        status: 'healthy',
        timestamp: nowUtc(),
        service: SERVER_METADATA.name,
        version: SERVER_METADATA.version,
      };
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(payload));
      return;
    }

    if (url.pathname === '/') {
      const payload = {
        service: SERVER_METADATA.displayName,
        version: SERVER_METADATA.version,
        status: 'running',
        timestamp: nowUtc(),
        endpoints: {
          health: '/healthz',
          mcp: 'stdio transport only',
        },
      };
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(payload));
      return;
    }

    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Not Found', path: url.pathname, timestamp: nowUtc() }));
  });

  server.on('error', (error) => {
    logger?.error?.(`HTTP server error: ${error.message}`);
  });

  const listen = (port, callback) => {
    server.listen(port, callback);
  };

  const close = () =>
    new Promise((resolve) => {
      server.close(() => resolve());
    });

  return { server, listen, close };
};
