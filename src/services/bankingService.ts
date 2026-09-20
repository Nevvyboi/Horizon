/**
 * The banking facade the app talks to.
 *
 * It hides which adapter is live and layers the transaction intelligence on
 * top, so components ask for "the account, the balance, the annotated
 * transactions" and never learn whether the numbers came from mock data or the
 * Investec sandbox.
 *
 * Data source is chosen by VITE_DATA_SOURCE ("mock" | "live"). Live falls back
 * to mock if the sandbox proxy is unreachable, so a demo never dies on a flaky
 * network.
 */

import type { Account, Balance, Transaction } from "../types";
import { annotateRecurring } from "./transactionService";
import { toISO } from "../lib/format";
import { createMockAdapter } from "./adapters/mockAdapter";
import { createInvestecAdapter } from "./adapters/investecAdapter";
import type { BankAdapter } from "./adapters/types";

export interface BankSnapshot {
  account: Account;
  balance: Balance;
  transactions: Transaction[]; // annotated with recurring info, newest first
  source: string; // adapter label actually used
  usedFallback: boolean;
}

const today = toISO(new Date());

function preferredSource(): "mock" | "live" {
  const v = (import.meta.env.VITE_DATA_SOURCE as string | undefined)?.toLowerCase();
  return v === "live" ? "live" : "mock";
}

async function load(adapter: BankAdapter): Promise<Omit<BankSnapshot, "usedFallback">> {
  const accounts = await adapter.getAccounts();
  const account = accounts[0];
  const [balance, transactions] = await Promise.all([
    adapter.getBalance(account.id),
    adapter.getTransactions(account.id),
  ]);
  return {
    account,
    balance,
    transactions: annotateRecurring(transactions, today),
    source: adapter.label,
  };
}

export async function getSnapshot(force?: "mock" | "live"): Promise<BankSnapshot> {
  const source = force ?? preferredSource();

  if (source === "live") {
    try {
      const snap = await load(createInvestecAdapter());
      return { ...snap, usedFallback: false };
    } catch {
      // Fall through to mock so the demo still runs.
      const snap = await load(createMockAdapter(today));
      return { ...snap, usedFallback: true };
    }
  }

  const snap = await load(createMockAdapter(today));
  return { ...snap, usedFallback: false };
}
