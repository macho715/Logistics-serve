import { DEFAULT_CURRENCY } from '../config/constants.js';

const currencyFormatter = new Intl.NumberFormat(DEFAULT_CURRENCY.locale, {
  style: 'currency',
  currency: DEFAULT_CURRENCY.code,
  maximumFractionDigits: DEFAULT_CURRENCY.maximumFractionDigits,
});

/**
 * 통화 값을 포맷합니다. (Formats numeric value as currency.)
 */
export const formatCurrency = (value) => currencyFormatter.format(Number(value || 0));

/**
 * 백분율 값을 문자열로 변환합니다. (Formats numeric value as percentage string.)
 */
export const formatPercent = (value, fractionDigits = 0) => `${Number(value).toFixed(fractionDigits)}%`;
