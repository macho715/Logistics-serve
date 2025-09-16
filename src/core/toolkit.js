import { McpError } from '../utils/assertions.js';

/**
 * MCP 도구를 나타냅니다. (Represents an MCP tool.)
 */
export class McpTool {
  constructor({ name, description, inputSchema, handler }) {
    this.name = name;
    this.description = description;
    this.inputSchema = inputSchema;
    this.handler = handler;
  }

  toSchema() {
    return {
      name: this.name,
      description: this.description,
      inputSchema: this.inputSchema,
    };
  }

  async execute(args, context) {
    return this.handler(args ?? {}, context ?? {});
  }
}

/**
 * MCP 도구 레지스트리입니다. (Registry managing MCP tools.)
 */
export class ToolRegistry {
  constructor(tools = []) {
    this.tools = new Map();
    tools.forEach((tool) => this.register(tool));
  }

  register(tool) {
    if (!(tool instanceof McpTool)) {
      throw new Error('ToolRegistry.register expects McpTool');
    }
    this.tools.set(tool.name, tool);
  }

  list() {
    return Array.from(this.tools.values()).map((tool) => tool.toSchema());
  }

  get(name) {
    return this.tools.get(name);
  }

  async run(name, args, context) {
    const tool = this.get(name);
    if (!tool) {
      throw new McpError('TOOL_NOT_FOUND', `Unknown tool: ${name}`);
    }
    return tool.execute(args, context);
  }
}
