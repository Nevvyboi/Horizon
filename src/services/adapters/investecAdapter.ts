/**
 * Live Investec sandbox adapter.
 *
 * It never holds credentials. It calls /api/investec/* on our own origin; the
 * Vite dev-server proxy (or, in a packaged build, a Tauri command) holds the
 * secret, does OAuth2 and forwards the read-only account calls. This keeps the
 * secret out of the browser bundle entirely.
 *
 * The Investec transactions API talks rands as plain numbers, so we keep the
 * amounts as-is and only attach a sign from the DEBIT/CREDIT type.
 */

import type { Account, Balance, Transaction } from "../../types";
import { categorise } from "../transactionService";
import type { BankAdapter } from "./types";

interface RawAccount {
  accountId: string;
  accountName?: string;
  referenceName?: string;
  accountNumber?: string;
  currency?: string;
}
interface RawBalance {
  accountId: string;
  currentBalance: number;
  availableBalance: number;
  currency?: string;
}
interface RawTransaction {
  type: "DEBIT" | "CREDIT";
  status?: string;
  description: string;
  amount: number; // rands
  postingDate?: string;
  transactionDate?: string;
}

export interface InvestecCredentials {
  clientId: string;
  secret: string;
  apiKey: string;
  environment: "sandbox" | "production";
}

/**
 * Hand the user's own Investec keys to the server-side proxy for this session.
 * The keys go straight to our own origin, are validated with a real token
 * request, and never touch the browser bundle or local storage.
 */
export async function setInvestecCredentials(creds: InvestecCredentials): Promise<void> {
  const res = await fetch("/api/investec/credentials", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(creds),
  });
  if (!res.ok) {
    const body = (await res.json().catch(() => ({}))) as { message?: string };
    throw new Error(body.message ?? `Could not connect with those keys (${res.status}).`);
  }
}

/** Forget any user keys and revert the proxy to its default session. */
export async function clearInvestecCredentials(): Promise<void> {
  await fetch("/api/investec/disconnect", { method: "POST" }).catch(() => {});
}

async function get<T>(path: string): Promise<T> {
  const res = await fetch(`/api/investec${path}`);
  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new Error((body as { message?: string }).message ?? `investec ${path} ${res.status}`);
  }
  const json = (await res.json()) as { data: T };
  return json.data;
}

export function createInvestecAdapter(): BankAdapter {
  return {
    id: "investec-sandbox",
    label: "Investec sandbox (Mr Smith)",

    async getAccounts(): Promise<Account[]> {
      const data = await get<{ accounts: RawAccount[] }>("/accounts");
      return data.accounts.map((a) => ({
        id: a.accountId,
        name: a.referenceName || a.accountName || "Account",
        number: a.accountNumber ?? "",
        currency: a.currency ?? "ZAR",
      }));
    },

    async getBalance(accountId: string): Promise<Balance> {
      const b = await get<RawBalance>(`/accounts/${accountId}/balance`);
      return {
        accountId: b.accountId ?? accountId,
        current: b.currentBalance,
        available: b.availableBalance,
        currency: b.currency ?? "ZAR",
      };
    },

    async getTransactions(accountId: string): Promise<Transaction[]> {
      const data = await get<{ transactions: RawTransaction[] }>(
        `/accounts/${accountId}/transactions`,
      );
      return data.transactions.map((t, i) => {
        const direction = t.type === "CREDIT" ? "in" : "out";
        const unsigned = Math.abs(t.amount);
        const date = (t.postingDate || t.transactionDate || "").slice(0, 10);
        return {
          id: `inv_${i}`,
          date,
          description: t.description,
          amount: direction === "in" ? unsigned : -unsigned,
          direction,
          category: categorise(t.description, direction),
          status: t.status?.toUpperCase() === "PENDING" ? "pending" : "posted",
        };
      });
    },
  };
}
