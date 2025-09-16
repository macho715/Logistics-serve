import { McpTool } from '../core/toolkit.js';
import { formatPercent } from '../utils/format.js';
import { hashToInt } from '../utils/hash.js';
import { validateContainerId } from '../utils/validation.js';

/**
 * 컨테이너 상태 스냅샷 도구입니다. (Provides container tracking snapshot.)
 */
export const containerStatusTool = new McpTool({
  name: 'check_container_status',
  description: 'ISO 6346 container tracking snapshot (deterministic)',
  inputSchema: {
    type: 'object',
    properties: {
      container_id: { type: 'string' },
    },
    required: ['container_id'],
  },
  handler: async (args, context) => {
    const containerId = validateContainerId(args.container_id);
    const seed = hashToInt(containerId);
    const progressPct = 50 + (seed % 41); // 50 - 90
    const vesselVoyage = `SD-${2025 + (seed % 3)}-${String(814 + (seed % 50)).padStart(4, '0')}`;

    const json = {
      ok: true,
      ts: context.now(),
      container_id: containerId,
      status: 'IN_TRANSIT',
      progress_pct: progressPct,
      location: {
        port: seed % 2 === 0 ? 'BUSAN' : 'JEBEL ALI',
        terminal: `T${1 + (seed % 4)}`,
      },
      vessel: {
        name: seed % 2 === 0 ? 'SAMSUNG DYNASTY' : 'ADNOC RELIANCE',
        voyage: vesselVoyage,
      },
      eta_utc: '2025-08-18T14:30:00Z',
      conditions: {
        temp_ok: true,
        humidity_ok: true,
        security_ok: true,
        docs_ok: true,
      },
    };

    const text = `📦 ${containerId} transit ${formatPercent(progressPct)}  Vessel:${json.vessel.name}  ETA:${json.eta_utc}`;

    return { json, text };
  },
});
