/** The default data source: deterministic synthetic data, no network. */

import type { Account, Balance, Transaction } from "../../types";
import { generateMockBank } from "../../data/mockBank";
import type { BankAdapter } from "./types";

export function createMockAdapter(today?: string): BankAdapter {
  const seed = generateMockBank(today);
  return {
    id: "mock",
    label: "Synthetic sandbox data",
    async getAccounts(): Promise<Account[]> {
      return [seed.account];
    },
    async getBalance(): Promise<Balance> {
      return seed.balance;
    },
    async getTransactions(): Promise<Transaction[]> {
      return seed.transactions;
    },
  };
}
