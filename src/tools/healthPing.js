import { McpTool } from '../core/toolkit.js';
import { clampString } from '../utils/strings.js';

/**
 * MCP health ping 도구입니다. (MCP health ping tool.)
 */
export const healthPingTool = new McpTool({
  name: 'health_ping',
  description: 'MCP health readiness probe',
  inputSchema: {
    type: 'object',
    properties: {
      echo: { type: 'string' },
    },
  },
  handler: async (args, context) => {
    const echo = clampString(args.echo ?? '');
    return {
      json: { ok: true, ts: context.now(), echo },
      text: `✅ health ping ${echo ? `echo:${echo}` : ''}`.trim(),
    };
  },
});
