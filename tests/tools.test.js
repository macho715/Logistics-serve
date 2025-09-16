import test from 'node:test';
import assert from 'node:assert/strict';

import { invoiceAuditTool } from '../src/tools/invoiceAudit.js';
import { shippingCostTool } from '../src/tools/shippingCost.js';
import { nowUtc } from '../src/utils/time.js';
import { enforceZeroGuard } from '../src/security/zeroGuard.js';

test('invoice audit tool returns validation payload', async () => {
  const context = { now: nowUtc, zeroGuard: enforceZeroGuard };
  const result = await invoiceAuditTool.execute(
    { invoice_path: 'HVDC-INV-123.pdf', incoterm: 'CFR', hs_code: '850490' },
    context,
  );
  assert.equal(result.json.ok, true);
  assert.equal(result.json.invoice_no.includes('HVDC'), true);
  assert.equal(result.json.validations.incoterm.valid, true);
  assert.equal(result.json.validations.hs_code.valid, true);
});

test('shipping cost tool calculates totals', async () => {
  const context = { now: nowUtc, zeroGuard: enforceZeroGuard };
  const result = await shippingCostTool.execute(
    { equipment_type: 'Transformer', weight: 12000, origin_port: 'BUSAN', destination_port: 'JEBEL ALI', incoterm: 'DAP' },
    context,
  );
  assert.equal(result.json.ok, true);
  assert.equal(result.json.breakdown_usd.total > result.json.breakdown_usd.base, true);
  assert.equal(result.json.incoterm.code, 'DAP');
});
