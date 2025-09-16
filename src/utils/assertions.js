/**
 * MCP 도메인 오류를 표현합니다. (Represents an MCP domain error.)
 */
export class McpError extends Error {
  constructor(code, message, details = {}) {
    super(message);
    this.name = 'McpError';
    this.code = code;
    this.details = details;
  }
}

/**
 * 조건을 검증하고 실패 시 MCP 오류를 던집니다. (Asserts a condition and throws an MCP error on failure.)
 */
export const assertOrThrow = (condition, code, message, details = {}) => {
  if (!condition) {
    throw new McpError(code, message, details);
  }
};
