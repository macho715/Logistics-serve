import test from 'node:test';
import assert from 'node:assert/strict';

import { validateContainerId, validateHsCode, validateIncoterm } from '../src/utils/validation.js';
import { enforceZeroGuard } from '../src/security/zeroGuard.js';
import { ZERO_GUARD_THRESHOLDS } from '../src/config/constants.js';

test('validateIncoterm recognises supported code', () => {
  const result = validateIncoterm('cfr');
  assert.equal(result.valid, true);
  assert.equal(result.code, 'CFR');
});

test('validateIncoterm flags unknown code', () => {
  const result = validateIncoterm('abc');
  assert.equal(result.valid, false);
  assert.equal(result.reason, 'UNKNOWN_INCOTERM');
});

test('validateHsCode returns description', () => {
  const result = validateHsCode('850490');
  assert.equal(result.valid, true);
  assert.ok(result.description.includes('Parts'));
});

test('validateHsCode handles unknown codes', () => {
  const result = validateHsCode('999999');
  assert.equal(result.valid, false);
  assert.equal(result.reason, 'UNKNOWN_HS_CODE');
});

test('validateContainerId normalises identifier', () => {
  const value = validateContainerId('abcd1234567');
  assert.equal(value, 'ABCD1234567');
});

test('enforceZeroGuard passes under threshold', () => {
  enforceZeroGuard({ hsRisk: ZERO_GUARD_THRESHOLDS.hsRiskStop - 0.01, certMissing: false });
});

test('enforceZeroGuard blocks high risk', () => {
  assert.throws(
    () => enforceZeroGuard({ hsRisk: ZERO_GUARD_THRESHOLDS.hsRiskStop + 0.1 }),
    (error) => error.code === 'HS_RISK_STOP',
  );
});
