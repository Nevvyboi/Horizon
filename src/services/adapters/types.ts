import type { Account, Balance, Transaction } from "../../types";

/**
 * The one interface the app depends on. Swap the implementation (mock, live
 * sandbox, a future Tauri command) without touching any UI or the forecast.
 */
export interface BankAdapter {
  id: string;
  label: string;
  getAccounts(): Promise<Account[]>;
  getBalance(accountId: string): Promise<Balance>;
  getTransactions(accountId: string): Promise<Transaction[]>;
}
