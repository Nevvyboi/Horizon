/**
 * The shared shapes for BalanceBar.
 *
 * These deliberately sit close to what the Investec API returns so the mock
 * adapter and the live adapter can be swapped without the app noticing. The
 * app-facing types (Forecast, ForecastPoint, UpcomingEvent) are ours.
 */

export type Direction = "in" | "out";

/** Broad buckets we sort transactions into for the UI and the spend estimate. */
export type Category =
  | "income"
  | "housing"
  | "transport"
  | "groceries"
  | "eating-out"
  | "subscriptions"
  | "insurance"
  | "utilities"
  | "health"
  | "debt"
  | "savings"
  | "shopping"
  | "cash"
  | "other";

/** A single posted or pending transaction, normalised from the bank feed. */
export interface Transaction {
  id: string;
  date: string; // ISO yyyy-mm-dd
  description: string;
  /** Signed amount in rands. Positive is money in, negative is money out. */
  amount: number;
  direction: Direction;
  category: Category;
  status: "posted" | "pending";
  /** Set by the transaction service when a repeating pattern is detected. */
  recurring?: RecurringInfo;
  /** A short user note, e.g. "Client meeting". */
  note?: string;
}

export interface RecurringInfo {
  isRecurring: boolean;
  /** 0..1. How sure we are this repeats, based on how regular it has been. */
  confidence: number;
  /** Rough gap between occurrences, in days. */
  cadenceDays: number;
  /** Best guess at the next date it lands, ISO yyyy-mm-dd. */
  nextDate: string;
  /** Typical amount in rands (unsigned). */
  typicalAmount: number;
}

export interface Account {
  id: string;
  name: string;
  number: string;
  currency: string; // "ZAR"
}

export interface Balance {
  accountId: string;
  current: number;
  available: number;
  currency: string;
}

/** A known future money movement the forecast is built from. */
export interface UpcomingEvent {
  id: string;
  date: string; // ISO yyyy-mm-dd
  label: string;
  amount: number; // signed, rands
  direction: Direction;
  category: Category;
  kind: "recurring" | "known" | "estimated-spend";
  confidence: number; // 0..1
  note?: string;
}

/** One day on the projected balance curve. */
export interface ForecastPoint {
  date: string; // ISO yyyy-mm-dd
  dayOffset: number; // days from today
  balance: number; // projected end-of-day balance, rands
  events: UpcomingEvent[]; // what moved money that day
}

/** The plain-language reasons the forecast came out the way it did. */
export interface ForecastAssumptions {
  historyMonths: number;
  recurringCount: number;
  expectedIncome: number;
  avgDailySpend: number;
  notes: string[];
}

export type Outlook = "comfortable" | "tight" | "low";

export interface Forecast {
  startBalance: number;
  horizonDays: number;
  points: ForecastPoint[];
  /** The lowest point on the curve, the number that actually matters. */
  lowest: { date: string; balance: number; dayOffset: number };
  /** Balance at the end of the horizon. */
  projected: number;
  outlook: Outlook;
  assumptions: ForecastAssumptions;
  /** Signed totals over the horizon, for the "Why?" breakdown. */
  breakdown: {
    startBalance: number;
    expectedIncome: number;
    recurringPayments: number; // negative
    typicalSpending: number; // negative
    projected: number;
  };
}

/** A scenario is a hypothetical layered on top of the base forecast. */
export interface Scenario {
  id: string;
  label: string;
  /** Extra one-off events to inject. */
  extraEvents?: UpcomingEvent[];
  /** Shift the main salary by this many days. */
  incomeShiftDays?: number;
  /** Multiply estimated daily spend by this (e.g. 0.7 to cut back). */
  spendMultiplier?: number;
  /** Cancel a recurring payment by description match. */
  cancelRecurring?: string;
}
