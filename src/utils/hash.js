/**
 * 문자열을 해시하여 결정적 정수를 생성합니다. (Hashes a string into a deterministic integer.)
 */
export const hashToInt = (value) => {
  const seed = [...String(value ?? '')].reduce((acc, char) => (acc * 33 + char.charCodeAt(0)) >>> 0, 5381);
  return seed >>> 0;
};
