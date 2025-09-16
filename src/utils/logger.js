import { LOG_TAG } from '../config/constants.js';
import { nowUtc } from './time.js';

/**
 * 표준화된 로거를 만듭니다. (Creates a standardized logger.)
 */
export const createLogger = (scope) => {
  const prefix = `[${LOG_TAG}${scope ? `:${scope}` : ''}]`;
  return {
    info: (message) => console.error(`${prefix}[${nowUtc()}] INFO ${message}`),
    warn: (message) => console.error(`${prefix}[${nowUtc()}] WARN ${message}`),
    error: (message) => console.error(`${prefix}[${nowUtc()}] ERROR ${message}`),
  };
};
