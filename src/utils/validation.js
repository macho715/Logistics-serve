import { assertOrThrow } from './assertions.js';
import { clampString } from './strings.js';
import { getIncotermSet, getHsCodeMap } from '../domain/referenceData.js';

const ISO_CONTAINER_REGEX = /^[A-Z]{4}\d{7}$/;
const INVOICE_REGEX = /(AE\d{6,}|HVDC[-_]INV[-_]\d{3,}|INV[-_]\d{3,}|\d{8})/i;

/**
 * 인보이스 경로에서 식별자를 추출합니다. (Extracts invoice identifier from path.)
 */
export const extractInvoiceNumber = (invoicePath) => {
  const match = clampString(invoicePath).match(INVOICE_REGEX);
  return match ? match[0].toUpperCase() : 'HVDC-INV-001';
};

/**
 * ISO 6346 컨테이너 ID를 검증합니다. (Validates ISO 6346 container identifier.)
 */
export const validateContainerId = (value) => {
  const id = clampString(value, 50).toUpperCase();
  assertOrThrow(ISO_CONTAINER_REGEX.test(id), 'BAD_INPUT', 'container_id must be ISO 6346 compliant');
  return id;
};

/**
 * 인코텀 코드를 검증합니다. (Validates Incoterm code.)
 */
export const validateIncoterm = (incoterm) => {
  if (!incoterm) {
    return { valid: false, code: undefined, reason: 'MISSING' };
  }
  const normalized = clampString(incoterm, 8).toUpperCase();
  const incoterms = getIncotermSet();
  const valid = incoterms.has(normalized);
  return {
    valid,
    code: normalized,
    reason: valid ? 'OK' : 'UNKNOWN_INCOTERM',
  };
};

/**
 * HS 코드를 검증합니다. (Validates HS code against reference data.)
 */
export const validateHsCode = (hsCode) => {
  if (!hsCode) {
    return { valid: false, code: undefined, description: undefined, reason: 'MISSING' };
  }
  const normalized = clampString(hsCode, 10).replace(/[^0-9]/g, '');
  const records = getHsCodeMap();
  const description = records.get(normalized);
  return {
    valid: Boolean(description),
    code: normalized,
    description,
    reason: description ? 'OK' : 'UNKNOWN_HS_CODE',
  };
};

/**
 * 무게가 양수인지 검증합니다. (Validates weight positivity.)
 */
export const validateWeight = (weight) => {
  const numeric = Number(weight);
  assertOrThrow(Number.isFinite(numeric) && numeric > 0, 'BAD_INPUT', 'weight must be greater than zero');
  return numeric;
};
