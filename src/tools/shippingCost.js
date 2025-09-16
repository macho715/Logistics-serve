import { McpTool } from '../core/toolkit.js';
import { clampString } from '../utils/strings.js';
import { formatCurrency } from '../utils/format.js';
import { validateIncoterm, validateWeight } from '../utils/validation.js';

/**
 * HVDC 운송 비용을 계산합니다. (Calculates HVDC shipping cost.)
 */
export const shippingCostTool = new McpTool({
  name: 'calculate_hvdc_shipping_cost',
  description: 'HVDC shipping cost calc with DEM/DET placeholders',
  inputSchema: {
    type: 'object',
    properties: {
      equipment_type: { type: 'string' },
      weight: { type: 'number' },
      origin_port: { type: 'string' },
      destination_port: { type: 'string' },
      incoterm: { type: 'string' },
    },
    required: ['equipment_type', 'weight', 'origin_port', 'destination_port'],
  },
  handler: async (args, context) => {
    const equipmentType = clampString(args.equipment_type, 80).toUpperCase();
    const weightKg = validateWeight(args.weight);
    const origin = clampString(args.origin_port, 80);
    const destination = clampString(args.destination_port, 80);
    const incotermValidation = validateIncoterm(args.incoterm ?? 'CFR');

    const base = 15000;
    const weightCost = Math.ceil(weightKg * 2.8);
    const hvdcHandling = Math.round(base * 0.3);
    const insurance = Math.round((base + weightCost) * 0.05);
    const demurrageReserve = 2800;
    const detentionReserve = 1800;
    const total = base + weightCost + hvdcHandling + insurance + demurrageReserve + detentionReserve;

    const json = {
      ok: true,
      ts: context.now(),
      equipment: equipmentType,
      route: { origin, destination },
      weight_kg: weightKg,
      incoterm: incotermValidation,
      breakdown_usd: {
        base,
        weight: weightCost,
        hvdc_handling: hvdcHandling,
        insurance,
        demurrage_reserve: demurrageReserve,
        detention_reserve: detentionReserve,
        total,
      },
      notes: ['Port-to-port', 'HVDC handling', 'Tracking', 'Security'],
    };

    const text =
      `💰 Cost ${formatCurrency(total)}  (${formatCurrency(base)} base / ${formatCurrency(weightCost)} weight / ` +
      `${formatCurrency(hvdcHandling)} hvdc / ${formatCurrency(insurance)} ins)`;

    return { json, text };
  },
});
