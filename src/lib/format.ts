/** Small formatting helpers. Rands everywhere, tight tracking in the UI. */

const zar = new Intl.NumberFormat("en-ZA", {
  style: "currency",
  currency: "ZAR",
  maximumFractionDigits: 0,
});

const zarCents = new Intl.NumberFormat("en-ZA", {
  style: "currency",
  currency: "ZAR",
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
});

/** R24,850, the headline format, no cents. */
export function money(amount: number): string {
  return zar.format(amount).replace("ZAR", "R").replace("R ", "R");
}

/** R199.00, used in transaction detail where cents matter. */
export function moneyCents(amount: number): string {
  return zarCents.format(amount).replace("ZAR", "R").replace("R ", "R");
}

/** +R32,000 / −R8,500 with a real minus sign, for money movements. */
export function signedMoney(amount: number): string {
  const sign = amount >= 0 ? "+" : "−";
  return `${sign}${money(Math.abs(amount))}`;
}

export function toISO(d: Date): string {
  return d.toISOString().slice(0, 10);
}

export function addDays(iso: string, days: number): string {
  const d = new Date(iso + "T00:00:00");
  d.setDate(d.getDate() + days);
  return toISO(d);
}

export function daysBetween(a: string, b: string): number {
  const da = new Date(a + "T00:00:00").getTime();
  const db = new Date(b + "T00:00:00").getTime();
  return Math.round((db - da) / 86_400_000);
}

/** "TODAY", "TOMORROW", or "25 SEP". */
export function relativeDay(iso: string, today: string): string {
  const diff = daysBetween(today, iso);
  if (diff === 0) return "TODAY";
  if (diff === 1) return "TOMORROW";
  const d = new Date(iso + "T00:00:00");
  const day = d.getDate();
  const month = d.toLocaleString("en-ZA", { month: "short" }).toUpperCase();
  return `${day} ${month}`;
}

export function shortDate(iso: string): string {
  const d = new Date(iso + "T00:00:00");
  return d.toLocaleString("en-ZA", { day: "numeric", month: "long" });
}
