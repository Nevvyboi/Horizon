/**
 * Transaction intelligence.
 *
 * Two jobs, both deliberately simple and explainable:
 *   1. categorise() turns a raw merchant string into one of our buckets.
 *   2. detectRecurring() finds transactions that repeat on a regular cadence
 *      (subscriptions, debit orders, salary) and scores how sure we are.
 *
 * Nothing here is magic or learned. It is keyword matching and interval
 * regularity, so every label the UI shows can be traced back to a rule.
 */

import type { Category, Direction, RecurringInfo, Transaction } from "../types";
import { addDays, daysBetween, toISO } from "../lib/format";

const RULES: Array<{ match: RegExp; category: Category }> = [
  { match: /salary|payroll|wages|acme corp|income|deposit|eft credit|payment received/i, category: "income" },
  { match: /rent|home loan|bond|landlord|levy|body corporate|municipal rates/i, category: "housing" },
  { match: /uber|bolt|gautrain|shell|engen|bp|sasol|total|caltex|petrol|garage|parking|e-toll|licen[cs]e/i, category: "transport" },
  { match: /woolworths|checkers|pick n pay|pnp|spar|shoprite|food lover|grocer|boxer|usave/i, category: "groceries" },
  { match: /uber eats|mr d|nando|kfc|steers|spur|wimpy|debonairs|roman|cafe|caffe|restaurant|bar |mcdonald|starbucks|vida|kauai|rocomamas/i, category: "eating-out" },
  { match: /netflix|spotify|showmax|youtube|apple\.com|itunes|disney|dstv|prime|icloud|adobe|chatgpt|openai|microsoft|google|dropbox|canva|subscription/i, category: "subscriptions" },
  { match: /outsurance|discovery insure|santam|momentum|old mutual|hollard|budget insur|miway|king price|insur/i, category: "insurance" },
  { match: /vodacom|mtn|telkom|cell c|rain|afrihost|webafrica|city power|eskom|joburg water|water|electric|prepaid|utilit/i, category: "utilities" },
  { match: /discovery health|medical aid|bonitas|momentum health|dischem|clicks|pharmac|gym|virgin active|planet fitness|dentist|doctor|hospital/i, category: "health" },
  { match: /vehicle finance|credit card|loan repayment|wesbank|mfc|personal loan|nedbank loan|installment/i, category: "debt" },
  { match: /transfer to savings|save|invest|tfsa|unit trust|easyequities|retirement|annuity|32day|money market/i, category: "savings" },
  { match: /takealot|amazon|superbalist|zara|cotton on|mr price|edgars|game|makro|incredible|builders|leroy|hi-fi|apple store/i, category: "shopping" },
  { match: /atm|cash withdrawal|withdrawal|cash send|cash@till/i, category: "cash" },
];

export function categorise(description: string, direction: Direction): Category {
  for (const rule of RULES) {
    if (rule.match.test(description)) return rule.category;
  }
  return direction === "in" ? "income" : "other";
}

/** Strip trailing store numbers, dates and city names so repeats group. */
function normaliseKey(description: string): string {
  return description
    .toUpperCase()
    .replace(/\d{2,}/g, "")
    .replace(/\b(SANDTON|JOBURG|JHB|CPT|CAPE TOWN|N1|SA|ZA|PREMIUM|TAP)\b/g, "")
    .replace(/[^A-Z ]/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

function median(values: number[]): number {
  const s = [...values].sort((a, b) => a - b);
  const mid = Math.floor(s.length / 2);
  return s.length % 2 ? s[mid] : (s[mid - 1] + s[mid]) / 2;
}

/**
 * Group transactions by normalised merchant, then flag any group that fired
 * at least 3 times on a fairly steady interval. Confidence blends how many
 * times we have seen it with how regular the gaps are.
 */
export function detectRecurring(
  transactions: Transaction[],
  today: string,
): Map<string, RecurringInfo> {
  const groups = new Map<string, Transaction[]>();
  for (const tx of transactions) {
    const key = normaliseKey(tx.description);
    if (!key) continue;
    const list = groups.get(key) ?? [];
    list.push(tx);
    groups.set(key, list);
  }

  const result = new Map<string, RecurringInfo>();

  for (const [, list] of groups) {
    if (list.length < 3) continue;
    const dates = list.map((t) => t.date).sort();
    const gaps: number[] = [];
    for (let i = 1; i < dates.length; i++) gaps.push(daysBetween(dates[i - 1], dates[i]));
    const cadence = Math.round(median(gaps));
    if (cadence < 5 || cadence > 45) continue; // weekly..monthly only

    // Regularity: how tight are the gaps around the median? Real debit orders
    // and salaries land on almost the same interval every time; noisy card
    // spending at the same shop does not, so it fails this test.
    const spread = gaps.reduce((sum, g) => sum + Math.abs(g - cadence), 0) / gaps.length;
    const regularity = Math.max(0, 1 - spread / (cadence * 0.5));
    if (regularity < 0.6) continue; // too irregular to call recurring
    const volume = Math.min(1, list.length / 3);
    const confidence = Math.min(0.99, 0.7 * regularity + 0.3 * volume);
    if (confidence < 0.75) continue;

    const last = dates[dates.length - 1];
    let nextDate = addDays(last, cadence);
    // Roll forward until the predicted date is in the future.
    while (daysBetween(today, nextDate) < 0) nextDate = addDays(nextDate, cadence);

    const info: RecurringInfo = {
      isRecurring: true,
      confidence,
      cadenceDays: cadence,
      nextDate,
      typicalAmount: Math.round(median(list.map((t) => Math.abs(t.amount)))),
    };
    for (const tx of list) result.set(tx.id, info);
  }

  return result;
}

/** Attach recurring info onto the transactions in place of returning a map. */
export function annotateRecurring(transactions: Transaction[], today = toISO(new Date())): Transaction[] {
  const info = detectRecurring(transactions, today);
  return transactions.map((tx) => ({ ...tx, recurring: info.get(tx.id) }));
}
