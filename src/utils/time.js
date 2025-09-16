/**
 * 현재 시간을 UTC ISO 문자열로 반환합니다. (Returns current time as UTC ISO string.)
 */
export const nowUtc = () => new Date().toISOString();

/**
 * 입력값을 UTC ISO 문자열로 파싱합니다. (Parses input into a UTC ISO string.)
 */
export const toIsoUtc = (value) => {
  const date = value instanceof Date ? value : new Date(value ?? Date.now());
  if (Number.isNaN(date.getTime())) {
    throw new Error('Invalid date value supplied');
  }
  return date.toISOString();
};
