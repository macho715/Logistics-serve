const PROMPTS = [
  {
    name: 'invoice_audit_summary',
    description: 'Summarize invoice audit (KR+EN, 1 line)',
    messages: [
      {
        role: 'system',
        content: [
          { type: 'text', text: 'Provide KR concise summary + EN-KR one line. Include Incoterm/HS/DEM-DET.' },
        ],
      },
    ],
  },
  {
    name: 'eta_explain',
    description: 'Explain ETA drivers (weather, berth, customs)',
    messages: [
      {
        role: 'system',
        content: [{ type: 'text', text: 'Break down ETA into Weather, Berth, Customs, Trucking.' }],
      },
    ],
  },
];

/**
 * 프롬프트 목록을 반환합니다. (Returns list of prompts.)
 */
export const listPrompts = () => PROMPTS.map(({ name, description }) => ({ name, description }));

/**
 * 프롬프트 세부 정보를 조회합니다. (Retrieves prompt detail by name.)
 */
export const getPromptByName = (name) => PROMPTS.find((prompt) => prompt.name === name);
