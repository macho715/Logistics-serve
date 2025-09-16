import { ZERO_GUARD_THRESHOLDS } from '../config/constants.js';
import { McpError } from '../utils/assertions.js';

/**
 * ZERO 안전 규칙을 평가합니다. (Evaluates ZERO guard safety rules.)
 */
export const enforceZeroGuard = (context = {}) => {
  const { hsRisk = 0, certMissing = false } = context;

  if (hsRisk >= ZERO_GUARD_THRESHOLDS.hsRiskStop) {
    throw new McpError('HS_RISK_STOP', 'High HS risk requires manual review');
  }

  if (certMissing) {
    throw new McpError('CERT_MISSING', 'FANR/MOIAT certification missing');
  }
};
