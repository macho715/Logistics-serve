/**
 * 문자열을 안전하게 자릅니다. (Safely clamps a string value.)
 */
export const clampString = (value, maxLength = 256) => {
  if (value === null || value === undefined) {
    return '';
  }
  return String(value).slice(0, maxLength);
};
