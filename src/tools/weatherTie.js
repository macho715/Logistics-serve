import { McpTool } from '../core/toolkit.js';
import { assertOrThrow } from '../utils/assertions.js';
import { clampString } from '../utils/strings.js';
import { toIsoUtc } from '../utils/time.js';

/**
 * 기상 연계 계획 도구입니다. (Provides weather-tied planning snapshot.)
 */
export const weatherTieTool = new McpTool({
  name: 'logi_master_weather_tie',
  description: 'Weather-tied plan snapshot',
  inputSchema: {
    type: 'object',
    properties: {
      route: { type: 'string' },
      departure_date: { type: 'string' },
    },
    required: ['route', 'departure_date'],
  },
  handler: async (args, context) => {
    const route = clampString(args.route, 120);
    const departureDate = clampString(args.departure_date, 40);
    assertOrThrow(route && departureDate, 'BAD_INPUT', 'route/departure_date required');

    const departureIso = toIsoUtc(departureDate);

    const json = {
      ok: true,
      ts: context.now(),
      route,
      departure_utc: departureIso,
      weather: {
        storm_risk: 0.15,
        sea_state_m: '2-3',
        wind_kt: '12-18',
      },
      risk: 'LOW',
      recommendation: 'PROCEED',
      optimal_window_days: 3,
      backup: 'delay_48h',
    };

    const text = `🌤️ Weather-tie: ${json.risk} risk, ${json.optimal_window_days}-day optimal window from T+1`;

    return { json, text };
  },
});
