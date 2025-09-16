/**
 * MCP 성공 응답을 생성합니다. (Creates an MCP success response.)
 */
export const createOkResponse = (json, text) => ({
  content: [{ type: 'json', json }, ...(text ? [{ type: 'text', text }] : [])],
});

/**
 * MCP 실패 응답을 생성합니다. (Creates an MCP error response.)
 */
export const createErrorResponse = (code, details = {}) => ({
  content: [{ type: 'json', json: { ok: false, code, ...details } }],
  isError: true,
});
