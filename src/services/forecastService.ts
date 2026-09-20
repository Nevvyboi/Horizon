/**
 * The forecast engine.
 *
 * There is no black box here. The projection is built from a short, honest
 * pipeline, and every number it produces can be traced back to a step:
 *
 *   1. Start from the current available balance.
 *   2. Find the recurring payments and income (from the transaction history).
 *   3. Estimate normal daily spending (average of recent non-recurring outflow).
 *   4. Lay the known recurring events onto a calendar across the horizon.
 *   5. Add the estimated daily spend on top.
 *   6. Walk day by day to get a projected balance for each day.
 *   7. Find the lowest point, the number that actually matters.
 *   8. Surface the assumptions and any obvious risks.
 *
 * Scenarios ("what if I spend R5,000", "salary 3 days late") are the same
 * pipeline with the event list nudged before the walk, so a scenario is always
 * explainable in the same terms as the base forecast.
 */

import type {
  Balance,
  Forecast,
  ForecastPoint,
  Outlook,
  Scenario,
  Transaction,
  UpcomingEvent,
} from "../types";
import { addDays, daysBetween } from "../lib/format";

interface RecurringGroup {
  key: string;
  description: string;
  direction: "in" | "out";
  category: Transaction["category"];
  cadenceDays: number;
  nextDate: string;
  typicalAmount: number;
  confidence: number;
}

function groupKey(description: string): string {
  return description
    .toUpperCase()
    .replace(/\d{2,}/g, "")
    .replace(/[^A-Z ]/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

/** Collapse annotated transactions into one entry per recurring commitment. */
function recurringGroups(transactions: Transaction[]): RecurringGroup[] {
  const seen = new Map<string, RecurringGroup>();
  for (const tx of transactions) {
    if (!tx.recurring?.isRecurring) continue;
    const key = groupKey(tx.description);
    if (seen.has(key)) continue;
    seen.set(key, {
      key,
      description: tx.description,
      direction: tx.direction,
      category: tx.category,
      cadenceDays: tx.recurring.cadenceDays,
      nextDate: tx.recurring.nextDate,
      typicalAmount: tx.recurring.typicalAmount,
      confidence: tx.recurring.confidence,
    });
  }
  return [...seen.values()];
}

/** Average daily outflow from the last `window` days, ignoring recurring items. */
function estimateDailySpend(transactions: Transaction[], today: string, window = 60): number {
  const cutoff = addDays(today, -window);
  let total = 0;
  for (const tx of transactions) {
    if (tx.direction !== "out") continue;
    if (tx.recurring?.isRecurring) continue;
    if (tx.date < cutoff || tx.date > today) continue;
    total += Math.abs(tx.amount);
  }
  return Math.round(total / window);
}

/** Expand recurring groups into dated events across the horizon. */
function recurringEvents(groups: RecurringGroup[], today: string, horizon: number): UpcomingEvent[] {
  const events: UpcomingEvent[] = [];
  const end = addDays(today, horizon);
  for (const g of groups) {
    let date = g.nextDate;
    // roll into range
    while (daysBetween(today, date) < 0) date = addDays(date, g.cadenceDays);
    let n = 0;
    while (date <= end) {
      events.push({
        id: `${g.key}-${date}`,
        date,
        label: titleCase(g.description),
        amount: g.direction === "in" ? g.typicalAmount : -g.typicalAmount,
        direction: g.direction,
        category: g.category,
        kind: "recurring",
        confidence: g.confidence,
      });
      date = addDays(date, g.cadenceDays);
      if (++n > 6) break; // guard
    }
  }
  return events;
}

function titleCase(s: string): string {
  return s
    .toLowerCase()
    .replace(/\b\w/g, (c) => c.toUpperCase())
    .replace(/\b(Sa|Za)\b/g, (m) => m.toUpperCase());
}

function outlookFor(lowest: number, monthlyCommitments: number): Outlook {
  if (lowest > monthlyCommitments) return "comfortable";
  if (lowest > monthlyCommitments * 0.25) return "tight";
  return "low";
}

export interface BuildOptions {
  horizonDays?: number;
  scenario?: Scenario;
}

export function buildForecast(
  balance: Balance,
  transactions: Transaction[],
  today: string,
  options: BuildOptions = {},
): Forecast {
  const horizon = options.horizonDays ?? 30;
  const scenario = options.scenario;

  const groups = recurringGroups(transactions);
  let avgDailySpend = estimateDailySpend(transactions, today);

  // --- assemble the event calendar ---
  let events = recurringEvents(groups, today, horizon);

  if (scenario?.cancelRecurring) {
    const needle = scenario.cancelRecurring.toLowerCase();
    events = events.filter((e) => !e.label.toLowerCase().includes(needle));
  }
  if (scenario?.incomeShiftDays) {
    events = events.map((e) =>
      e.direction === "in" ? { ...e, date: addDays(e.date, scenario.incomeShiftDays!) } : e,
    );
  }
  if (scenario?.spendMultiplier != null) {
    avgDailySpend = Math.round(avgDailySpend * scenario.spendMultiplier);
  }

  // estimated daily spend as one event per future day
  const spendEvents: UpcomingEvent[] = [];
  for (let d = 1; d <= horizon; d++) {
    spendEvents.push({
      id: `spend-${d}`,
      date: addDays(today, d),
      label: "Typical spending",
      amount: -avgDailySpend,
      direction: "out",
      category: "other",
      kind: "estimated-spend",
      confidence: 0.7,
    });
  }

  const extra = scenario?.extraEvents ?? [];
  const allEvents = [...events, ...spendEvents, ...extra];

  // --- walk day by day ---
  const byDay = new Map<string, UpcomingEvent[]>();
  for (const e of allEvents) {
    const list = byDay.get(e.date) ?? [];
    list.push(e);
    byDay.set(e.date, list);
  }

  const points: ForecastPoint[] = [];
  let running = balance.available;
  points.push({ date: today, dayOffset: 0, balance: running, events: [] });
  for (let d = 1; d <= horizon; d++) {
    const date = addDays(today, d);
    const dayEvents = byDay.get(date) ?? [];
    for (const e of dayEvents) running += e.amount;
    points.push({ date, dayOffset: d, balance: Math.round(running), events: dayEvents });
  }

  // --- lowest point ---
  let lowest = points[0];
  for (const p of points) if (p.balance < lowest.balance) lowest = p;

  // --- breakdown, reconciled with the walk ---
  const income = sum(allEvents.filter((e) => e.direction === "in").map((e) => e.amount));
  const recurringOut = sum(
    allEvents.filter((e) => e.direction === "out" && e.kind === "recurring").map((e) => e.amount),
  );
  const spendOut = sum(
    allEvents
      .filter((e) => e.direction === "out" && e.kind !== "recurring")
      .map((e) => e.amount),
  );
  const projected = points[points.length - 1].balance;

  const monthlyCommitments = Math.abs(
    sum(groups.filter((g) => g.direction === "out").map((g) => -g.typicalAmount)),
  );

  const assumptions = {
    historyMonths: 3,
    recurringCount: groups.length,
    expectedIncome: income,
    avgDailySpend,
    notes: buildNotes(groups, income, avgDailySpend),
  };

  return {
    startBalance: balance.available,
    horizonDays: horizon,
    points,
    lowest: { date: lowest.date, balance: lowest.balance, dayOffset: lowest.dayOffset },
    projected,
    outlook: outlookFor(lowest.balance, monthlyCommitments || balance.available * 0.3),
    assumptions,
    breakdown: {
      startBalance: balance.available,
      expectedIncome: income,
      recurringPayments: recurringOut,
      typicalSpending: spendOut,
      projected,
    },
  };
}

function buildNotes(groups: RecurringGroup[], income: number, avgDailySpend: number): string[] {
  const notes: string[] = [];
  notes.push(`${groups.length} recurring payments detected`);
  notes.push("3 months of transaction history");
  if (income > 0) notes.push("Expected salary included");
  notes.push(`Average daily spending of about R${avgDailySpend.toLocaleString("en-ZA")}`);
  return notes;
}

function sum(xs: number[]): number {
  return xs.reduce((a, b) => a + b, 0);
}

export interface GlanceStats {
  outlook: Outlook;
  healthPct: number; // 0..1 ring fill for the health gauge
  daysToPayday: number | null;
  payCyclePct: number; // 0..1 progress through the current pay cycle
  spentThisMonth: number;
  typicalMonthly: number;
  spentPct: number; // 0..1 of typical monthly spend used so far
  lowest: number;
  bufferPct: number; // lowest relative to today's balance
}

/** The handful of at-a-glance numbers the ring gauges show. */
export function deriveGlanceStats(
  forecast: Forecast,
  transactions: Transaction[],
  today: string,
): GlanceStats {
  const txs = Array.isArray(transactions) ? transactions : [];
  const nextIncome = listUpcoming(forecast, 20).find((e) => e.direction === "in");
  const daysToPayday = nextIncome ? Math.max(0, daysBetween(today, nextIncome.date)) : null;
  const cycle = 30;
  const payCyclePct = daysToPayday == null ? 0 : clamp01((cycle - daysToPayday) / cycle);

  const month = today.slice(0, 7);
  let spentThisMonth = 0;
  for (const tx of txs) {
    if (tx.direction === "out" && tx.date.startsWith(month)) spentThisMonth += Math.abs(tx.amount);
  }
  const recurringMonthly = Math.abs(forecast.breakdown.recurringPayments);
  const typicalMonthly = forecast.assumptions.avgDailySpend * 30 + recurringMonthly;
  const spentPct = clamp01(typicalMonthly ? spentThisMonth / typicalMonthly : 0);

  const bufferPct = clamp01(forecast.lowest.balance / Math.max(1, forecast.startBalance));
  const healthPct =
    forecast.outlook === "comfortable" ? Math.max(0.66, bufferPct)
    : forecast.outlook === "tight" ? Math.min(0.6, Math.max(0.34, bufferPct))
    : Math.min(0.33, bufferPct);

  return {
    outlook: forecast.outlook,
    healthPct,
    daysToPayday,
    payCyclePct,
    spentThisMonth,
    typicalMonthly,
    spentPct,
    lowest: forecast.lowest.balance,
    bufferPct,
  };
}

function clamp01(n: number): number {
  return Math.max(0, Math.min(1, n));
}

/**
 * The discrete named events coming up (recurring + one-offs), newest first,
 * for the "Coming up" list and the radar. Estimated daily spend is left out on
 * purpose, it is noise in a list of events.
 */
export function listUpcoming(forecast: Forecast, limit = 8): UpcomingEvent[] {
  const events = forecast.points
    .flatMap((p) => p.events)
    .filter((e) => e.kind !== "estimated-spend")
    .sort((a, b) => (a.date < b.date ? -1 : 1));
  return events.slice(0, limit);
}
