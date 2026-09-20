import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { getSnapshot, type BankSnapshot } from "../services/bankingService";
import { buildForecast } from "../services/forecastService";
import {
  setInvestecCredentials,
  clearInvestecCredentials,
  type InvestecCredentials,
} from "../services/adapters/investecAdapter";
import type { Forecast, Scenario, Transaction } from "../types";
import { toISO } from "../lib/format";

const today = toISO(new Date());
const ONBOARD_KEY = "bb.onboarded.source";
const REFRESH_KEY = "bb.refreshMinutes";
const DEFAULT_REFRESH = 15;

export type SourceChoice = "mock" | "live";

export interface HorizonState {
  onboarded: boolean;
  loading: boolean;
  refreshing: boolean;
  snapshot: BankSnapshot | null;
  today: string;
  base: Forecast | null;
  forecastWith: (scenario?: Scenario) => Forecast | null;
  notes: Record<string, string>;
  setNote: (txId: string, note: string) => void;
  transactions: Transaction[];
  /** Minutes between automatic re-fetches from the bank. */
  refreshMinutes: number;
  setRefreshMinutes: (m: number) => void;
  /** When the current snapshot was last fetched. */
  lastUpdated: number | null;
  /** Re-fetch now, keeping the same data source. */
  refreshNow: () => Promise<void>;
  /**
   * Connect a data source. With `creds`, the user's own Investec keys are sent
   * to the server-side proxy first, then the live account is loaded.
   */
  connect: (source: SourceChoice, creds?: InvestecCredentials) => Promise<void>;
  /** Wipe the connection and return to the onboarding flow. */
  disconnect: () => void;
}

/** Allowed auto-refresh cadences, in minutes. */
export const REFRESH_STEPS = [5, 10, 15, 30, 60] as const;

function loadRefresh(): number {
  try {
    const v = Number(localStorage.getItem(REFRESH_KEY));
    return REFRESH_STEPS.includes(v as (typeof REFRESH_STEPS)[number]) ? v : DEFAULT_REFRESH;
  } catch {
    return DEFAULT_REFRESH;
  }
}

export function useHorizon(): HorizonState {
  const [snapshot, setSnapshot] = useState<BankSnapshot | null>(null);
  const [loading, setLoading] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const [onboarded, setOnboarded] = useState(false);
  const [notes, setNotes] = useState<Record<string, string>>({});
  const [refreshMinutes, setRefreshMinutesState] = useState<number>(loadRefresh);
  const [lastUpdated, setLastUpdated] = useState<number | null>(null);
  const sourceRef = useRef<SourceChoice | null>(null);

  const connect = useCallback(async (source: SourceChoice, creds?: InvestecCredentials) => {
    setLoading(true);
    // If the user attached their own keys, register them server-side first.
    // This throws on a bad key so the caller can surface the error.
    if (creds) await setInvestecCredentials(creds);
    const snap = await getSnapshot(source);
    sourceRef.current = source;
    setSnapshot(snap);
    setLastUpdated(Date.now());
    setOnboarded(true);
    setLoading(false);
    try {
      // Only the source label is persisted, never the secret.
      localStorage.setItem(ONBOARD_KEY, source);
    } catch {
      /* private mode: fine, just re-onboard next time */
    }
  }, []);

  const refreshNow = useCallback(async () => {
    const source = sourceRef.current;
    if (!source) return;
    setRefreshing(true);
    try {
      const snap = await getSnapshot(source);
      setSnapshot(snap);
      setLastUpdated(Date.now());
    } finally {
      setRefreshing(false);
    }
  }, []);

  const setRefreshMinutes = useCallback((m: number) => {
    setRefreshMinutesState(m);
    try {
      localStorage.setItem(REFRESH_KEY, String(m));
    } catch {
      /* ignore */
    }
  }, []);

  const disconnect = useCallback(() => {
    sourceRef.current = null;
    setSnapshot(null);
    setLastUpdated(null);
    setOnboarded(false);
    void clearInvestecCredentials();
    try {
      localStorage.removeItem(ONBOARD_KEY);
    } catch {
      /* ignore */
    }
  }, []);

  // Auto-reconnect if the user has been here before.
  useEffect(() => {
    let saved: string | null = null;
    try {
      saved = localStorage.getItem(ONBOARD_KEY);
    } catch {
      saved = null;
    }
    if (saved === "mock" || saved === "live") void connect(saved);
  }, [connect]);

  // Poll the bank on the chosen cadence while connected.
  useEffect(() => {
    if (!onboarded) return;
    const id = setInterval(() => void refreshNow(), refreshMinutes * 60_000);
    return () => clearInterval(id);
  }, [onboarded, refreshMinutes, refreshNow]);

  const base = useMemo(() => {
    if (!snapshot) return null;
    return buildForecast(snapshot.balance, snapshot.transactions, today);
  }, [snapshot]);

  const forecastWith = useCallback(
    (scenario?: Scenario) => {
      if (!snapshot) return null;
      if (!scenario) return base;
      return buildForecast(snapshot.balance, snapshot.transactions, today, { scenario });
    },
    [snapshot, base],
  );

  const setNote = useCallback((txId: string, note: string) => {
    setNotes((prev) => ({ ...prev, [txId]: note }));
  }, []);

  return {
    onboarded,
    loading,
    refreshing,
    snapshot,
    today,
    base,
    forecastWith,
    notes,
    setNote,
    transactions: snapshot?.transactions ?? [],
    refreshMinutes,
    setRefreshMinutes,
    lastUpdated,
    refreshNow,
    connect,
    disconnect,
  };
}
