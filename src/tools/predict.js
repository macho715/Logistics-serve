import { McpTool } from '../core/toolkit.js';
import { assertOrThrow } from '../utils/assertions.js';
import { clampString } from '../utils/strings.js';
import { hashToInt } from '../utils/hash.js';
import { validateWeight } from '../utils/validation.js';

/**
 * ETA/KPI 예측 도구입니다. (Provides deterministic ETA/KPI prediction.)
 */
export const predictTool = new McpTool({
  name: 'logi_master_predict',
  description: 'ETA/KPI prediction (deterministic seed)',
  inputSchema: {
    type: 'object',
    properties: {
      origin: { type: 'string' },
      destination: { type: 'string' },
      weight: { type: 'number' },
    },
    required: ['origin', 'destination', 'weight'],
  },
  handler: async (args, context) => {
    const origin = clampString(args.origin, 80);
    const destination = clampString(args.destination, 80);
    assertOrThrow(origin && destination, 'BAD_INPUT', 'origin/destination required');
    const weight = validateWeight(args.weight);

    const seed = hashToInt(`${origin}|${destination}|${weight}`);
    const etaDays = 7 + (seed % 7);
    const customsDays = 2 + (seed % 2);

    const json = {
      ok: true,
      ts: context.now(),
      route: { origin, destination },
      cargo_weight_kg: weight,
      eta_days: etaDays,
      confidence: 0.82 + (seed % 5) / 100,
      drivers: {
        weather: seed % 3 === 0 ? 'MODERATE' : 'LOW',
        port_congestion: seed % 4 === 0 ? 'MEDIUM' : 'LOW',
        customs_days: `${customsDays}-${customsDays + 1}`,
      },
      kpi_targets: {
        on_time_rate: 0.93,
        risk: seed % 2 === 0 ? 'LOW' : 'MEDIUM',
      },
    };

    const text = `🚢 ETA ${etaDays}d (conf ${(json.confidence * 100).toFixed(0)}%)  weather:${json.drivers.weather.toLowerCase()} / congestion:${json.drivers.port_congestion.toLowerCase()} / customs:${json.drivers.customs_days}d`;

    return { json, text };
  },
});
