/**
 * Synthetic banking data for the prototype.
 *
 * Everything here is fake and generated deterministically from a seed so the
 * demo looks the same every time. It is shaped to mirror the Investec sandbox
 * "Mr Smith" account: a salary, a handful of debit orders and subscriptions,
 * and noisy day-to-day card spending across ~3 months of history. That history
 * is what lets the recurring detector and the spend estimate do real work
 * instead of reading canned numbers.
 */

import type { Account, Balance, Transaction, Direction } from "../types";
import { addDays, toISO } from "../lib/format";
import { categorise } from "../services/transactionService";

/** Deterministic PRNG so the mock is stable across reloads. */
function mulberry32(seed: number) {
  return function () {
    seed |= 0;
    seed = (seed + 0x6d2b79f5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

interface RecurringSpec {
  description: string;
  amount: number; // unsigned rands
  direction: Direction;
  dayOfMonth: number;
}

/** Monthly commitments. Debits total R10,640, matched by the R32,000 salary. */
const RECURRING: RecurringSpec[] = [
  { description: "SALARY - MERIDIAN LABS", amount: 32000, direction: "in", dayOfMonth: 25 },
  { description: "RENT - GREENPOINT PROPERTIES", amount: 8500, direction: "out", dayOfMonth: 27 },
  { description: "OUTSURANCE", amount: 764, direction: "out", dayOfMonth: 1 },
  { description: "NETFLIX SA", amount: 199, direction: "out", dayOfMonth: 2 },
  { description: "SPOTIFY PREMIUM", amount: 79, direction: "out", dayOfMonth: 3 },
  { description: "VIRGIN ACTIVE", amount: 499, direction: "out", dayOfMonth: 4 },
  { description: "VODACOM", amount: 599, direction: "out", dayOfMonth: 5 },
];

/** Pool of everyday card merchants for the noisy daily spend. */
const DAILY_MERCHANTS: Array<{ name: string; min: number; max: number }> = [
  { name: "WOOLWORTHS FOOD", min: 280, max: 1240 },
  { name: "CHECKERS HYPER", min: 180, max: 890 },
  { name: "PICK N PAY", min: 120, max: 640 },
  { name: "UBER TRIP", min: 60, max: 260 },
  { name: "SHELL GARAGE", min: 550, max: 1150 },
  { name: "UBER EATS", min: 140, max: 420 },
  { name: "MR D FOOD", min: 130, max: 380 },
  { name: "VIDA E CAFFE", min: 42, max: 95 },
  { name: "NANDOS", min: 110, max: 320 },
  { name: "TAKEALOT.COM", min: 250, max: 1800 },
  { name: "DISCHEM", min: 90, max: 620 },
  { name: "GAUTRAIN", min: 45, max: 110 },
];

const ACCOUNT: Account = {
  id: "3353431574710163189587446",
  name: "Private Bank Account",
  number: "10012347821",
  currency: "ZAR",
};

const CURRENT_AVAILABLE = 24850;

export function generateMockBank(today = toISO(new Date())): {
  account: Account;
  balance: Balance;
  transactions: Transaction[];
} {
  const rand = mulberry32(20260920);
  const transactions: Transaction[] = [];
  const historyDays = 92;
  const start = addDays(today, -historyDays);

  let counter = 0;
  const push = (date: string, description: string, unsigned: number, direction: Direction) => {
    const amount = direction === "in" ? unsigned : -unsigned;
    transactions.push({
      id: `tx_${counter++}`,
      date,
      description,
      amount,
      direction,
      category: categorise(description, direction),
      status: "posted",
    });
  };

  // Walk day by day so recurring items land on their day-of-month and daily
  // spend accumulates naturally.
  for (let offset = -historyDays; offset <= 0; offset++) {
    const date = addDays(today, offset);
    const dom = new Date(date + "T00:00:00").getDate();

    for (const spec of RECURRING) {
      if (spec.dayOfMonth === dom) push(date, spec.description, spec.amount, spec.direction);
    }

    // A few card spends per day, a touch heavier on weekends. This sets the
    // "typical spending" the forecast learns, so it needs to be a realistic
    // daily-life amount, not token noise.
    const weekday = new Date(date + "T00:00:00").getDay();
    const isWeekend = weekday === 0 || weekday === 6;
    const spends = Math.floor(rand() * 2) + (isWeekend ? 2 : 2);
    for (let i = 0; i < spends; i++) {
      const m = DAILY_MERCHANTS[Math.floor(rand() * DAILY_MERCHANTS.length)];
      const amount = Math.round(m.min + rand() * (m.max - m.min));
      push(date, m.name, amount, "out");
    }
  }

  void start; // start is documented above; history is generated from `today`.

  // Reconcile: set available balance to the fixed hero figure regardless of the
  // random walk, so the headline is stable. current == available for a cheque
  // account with nothing pending here.
  const balance: Balance = {
    accountId: ACCOUNT.id,
    current: CURRENT_AVAILABLE,
    available: CURRENT_AVAILABLE,
    currency: "ZAR",
  };

  return {
    account: ACCOUNT,
    balance,
    transactions: transactions.sort((a, b) => (a.date < b.date ? 1 : -1)),
  };
}
