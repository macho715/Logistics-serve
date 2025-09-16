/**
 * 서버/도메인 상수를 정의합니다. (Defines server/domain constants.)
 */
export const SERVER_METADATA = Object.freeze({
  name: 'samsung-logistics-mcp',
  version: '1.2.0',
  displayName: 'Samsung Logistics MCP Server',
});

/**
 * HTTP 서버 기본 구성을 제공합니다. (Provides default HTTP server configuration.)
 */
export const HTTP_CONFIG = Object.freeze({
  defaultPort: 3000,
  cors: {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  },
});

/**
 * 로깅 태그를 지정합니다. (Defines logging tag.)
 */
export const LOG_TAG = 'SAMSUNG-MCP';

/**
 * 통화 기본값을 제공합니다. (Provides default currency configuration.)
 */
export const DEFAULT_CURRENCY = Object.freeze({
  code: 'USD',
  locale: 'en-US',
  maximumFractionDigits: 0,
});

/**
 * ZERO 안전 규칙 기본값입니다. (Defines ZERO guard defaults.)
 */
export const ZERO_GUARD_THRESHOLDS = Object.freeze({
  hsRiskStop: 0.8,
});
