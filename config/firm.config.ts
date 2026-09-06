/**
 * The only file you must edit to make this platform yours.
 *
 * User-facing text reads its labels from here rather than hardcoding them, so a firm
 * that says "family group" instead of "client group" changes one line, not forty.
 */

export const firm = {
  // --- identity -----------------------------------------------------------
  name: "Your Firm Pty Ltd",
  shortName: "Your Firm",
  wordmark: "YF",
  domain: "yourfirm.com.au",
  supportEmail: "admin@yourfirm.com.au",

  // --- Australian defaults, change only with a reason ----------------------
  locale: "en-AU",
  currency: "AUD",
  dateFormat: "dd/MM/yyyy",
  financialYearEndMonth: 6, // June

  // --- what your firm calls things ----------------------------------------
  terms: {
    client: "Client",
    clients: "Clients",
    clientGroup: "Client group",
    clientGroups: "Client groups",
    owner: "Manager",
    service: "Service",
    services: "Services",
  },

  // --- one accent, used sparingly ------------------------------------------
  // Primary actions and the active nav item only. Never for status: good, warning
  // and critical are semantic and separate.
  brand: {
    accent: "#2F5D62",
    accentForeground: "#FFFFFF",
  },
} as const;

export type Firm = typeof firm;

/** Financial year label for a date. 15 Mar 2027 in a June-end firm is FY2027. */
export function financialYear(date: Date, endMonth = firm.financialYearEndMonth): number {
  return date.getMonth() + 1 > endMonth ? date.getFullYear() + 1 : date.getFullYear();
}

/** Money, the way an Australian firm reads it: no cents on summary screens. */
export function money(value: number | null | undefined, cents = false): string {
  if (value === null || value === undefined || Number.isNaN(value)) return "-";
  return new Intl.NumberFormat(firm.locale, {
    style: "currency",
    currency: firm.currency,
    minimumFractionDigits: cents ? 2 : 0,
    maximumFractionDigits: cents ? 2 : 0,
  }).format(value);
}
