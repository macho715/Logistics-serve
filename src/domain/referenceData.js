import { readFileSync } from 'node:fs';
import { parse } from 'yaml';
import { nowUtc } from '../utils/time.js';

let cachedIncoterms;
let cachedHsCodes;

const loadYaml = (pathUrl) => {
  const raw = readFileSync(pathUrl, 'utf-8');
  return parse(raw);
};

const loadCsv = (pathUrl) => {
  const raw = readFileSync(pathUrl, 'utf-8');
  return raw
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);
};

const fallbackIncoterms = () => new Set(['EXW', 'FCA', 'FAS', 'FOB', 'CFR', 'CIF', 'CPT', 'CIP', 'DAP', 'DPU', 'DDP']);
const fallbackHsCodes = () =>
  new Map([
    ['850490', 'Parts for static converters'],
    ['850422', 'Transformers exceeding 650 kVA but not exceeding 10,000 kVA'],
    ['853710', 'Boards with voltage <= 1,000 V'],
  ]);

const loadIncoterms = () => {
  try {
    const data = loadYaml(new URL('../../resources/incoterm.yaml', import.meta.url));
    const items = Array.isArray(data?.incoterms) ? data.incoterms : [];
    return new Set(items.map((item) => String(item).toUpperCase()));
  } catch (error) {
    console.error(`[SAMSUNG-MCP][${nowUtc()}] WARN incoterm load failed: ${error.message}`);
    return fallbackIncoterms();
  }
};

const loadHsCodes = () => {
  try {
    const lines = loadCsv(new URL('../../resources/hs2022.csv', import.meta.url));
    const [, ...rows] = lines;
    const entries = rows.map((line) => {
      const [code, ...descriptionParts] = line.split(',');
      return [code.trim(), descriptionParts.join(',').trim()];
    });
    return new Map(entries.filter(([code, description]) => code && description));
  } catch (error) {
    console.error(`[SAMSUNG-MCP][${nowUtc()}] WARN hs code load failed: ${error.message}`);
    return fallbackHsCodes();
  }
};

/**
 * 인코텀 집합을 제공합니다. (Provides Incoterm set.)
 */
export const getIncotermSet = () => {
  if (!cachedIncoterms) {
    cachedIncoterms = loadIncoterms();
  }
  return cachedIncoterms;
};

/**
 * HS 코드 맵을 제공합니다. (Provides HS code map.)
 */
export const getHsCodeMap = () => {
  if (!cachedHsCodes) {
    cachedHsCodes = loadHsCodes();
  }
  return cachedHsCodes;
};
