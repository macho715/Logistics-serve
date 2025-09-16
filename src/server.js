import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  ListPromptsRequestSchema,
  ListToolsRequestSchema,
  GetPromptRequestSchema,
  CallToolRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';

import { SERVER_METADATA, HTTP_CONFIG } from './config/constants.js';
import { createHttpServer } from './http/httpServer.js';
import { ALL_TOOLS } from './tools/index.js';
import { ToolRegistry } from './core/toolkit.js';
import { listPrompts, getPromptByName } from './core/prompts.js';
import { createOkResponse, createErrorResponse } from './mcp/responses.js';
import { createLogger } from './utils/logger.js';
import { nowUtc } from './utils/time.js';
import { enforceZeroGuard } from './security/zeroGuard.js';

/**
 * 삼성 물류 MCP 서버입니다. (Samsung Logistics MCP server implementation.)
 */
export class SamsungLogisticsMcpServer {
  constructor() {
    this.logger = createLogger('SERVER');
    this.toolLogger = createLogger('TOOL');
    this.httpLogger = createLogger('HTTP');
    this.toolRegistry = new ToolRegistry(ALL_TOOLS);

    this.server = new Server(SERVER_METADATA, { capabilities: { tools: {}, prompts: {} } });
    this.setupHandlers();
    this.setupErrorHandling();
    this.registerShutdownHooks();
    this.setupHttpServer();
  }

  setupHandlers() {
    this.server.setRequestHandler(ListToolsRequestSchema, async () => ({
      tools: this.toolRegistry.list(),
    }));

    this.server.setRequestHandler(ListPromptsRequestSchema, async () => ({
      prompts: listPrompts(),
    }));

    this.server.setRequestHandler(GetPromptRequestSchema, async (request) => {
      const { name } = request.params;
      const prompt = getPromptByName(name);
      if (!prompt) {
        return createErrorResponse('PROMPT_NOT_FOUND', { name });
      }
      return { messages: prompt.messages };
    });

    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      try {
        const { name, arguments: args = {} } = request.params;
        this.toolLogger.info(`Call ${name}`);
        const result = await this.toolRegistry.run(name, args, this.createToolContext());
        return createOkResponse(result.json, result.text);
      } catch (error) {
        const code = error?.code || 'UNEXPECTED';
        const details = { ts: nowUtc(), message: String(error?.message ?? 'Unknown error') };
        if (error?.details) {
          details.details = error.details;
        }
        this.toolLogger.error(`Call failed: ${code} ${details.message}`);
        return createErrorResponse(code, details);
      }
    });
  }

  setupErrorHandling() {
    this.server.onerror = (error) => {
      const message = String(error?.message || error);
      this.logger.error(`Unhandled MCP error: ${message}`);
    };
  }

  registerShutdownHooks() {
    const stop = async () => {
      this.logger.warn('Graceful shutdown requested');
      if (this.httpController) {
        await this.httpController.close();
      }
    };
    process.on('SIGINT', stop);
    process.on('SIGTERM', stop);
  }

  setupHttpServer() {
    const port = Number(process.env.PORT) || HTTP_CONFIG.defaultPort;
    this.httpController = createHttpServer(this.httpLogger);
    this.httpController.listen(port, () => {
      this.httpLogger.info(`HTTP listening on port ${port}`);
    });
  }

  createToolContext() {
    return {
      now: nowUtc,
      zeroGuard: enforceZeroGuard,
      logger: this.toolLogger,
    };
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    this.logger.info(`${SERVER_METADATA.displayName} (v${SERVER_METADATA.version}) Ready`);
  }
}
