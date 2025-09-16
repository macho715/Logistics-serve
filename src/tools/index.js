import { healthPingTool } from './healthPing.js';
import { invoiceAuditTool } from './invoiceAudit.js';
import { containerStatusTool } from './containerStatus.js';
import { shippingCostTool } from './shippingCost.js';
import { predictTool } from './predict.js';
import { weatherTieTool } from './weatherTie.js';

/**
 * 등록된 MCP 도구 목록입니다. (Exports all registered MCP tools.)
 */
export const ALL_TOOLS = [
  healthPingTool,
  invoiceAuditTool,
  containerStatusTool,
  shippingCostTool,
  predictTool,
  weatherTieTool,
];
