import { useState } from "react";
import { motion } from "framer-motion";
import type { Forecast, Transaction, UpcomingEvent } from "../types";
import { money, signedMoney, relativeDay } from "../lib/format";
import { listUpcoming, deriveGlanceStats } from "../services/forecastService";
import { ForecastGraph } from "./ForecastGraph";
import { Gauge } from "./Gauge";
import { CategoryIcon, Sparkle, Gear, Radar, Wallet, Bolt, ChevronRight, HorizonMark } from "./icons";

const OUTLOOK_LABEL: Record<Forecast["outlook"], string> = {
  comfortable: "Comfortable",
  tight: "Getting tight",
  low: "Low buffer",
};

interface Props {
  forecast: Forecast;
  transactions: Transaction[];
  today: string;
  source: string;
  onOpenFuture: () => void;
  onOpenWhatsNext: () => void;
  onOpenSettings: () => void;
  onSelectEvent: (e: UpcomingEvent) => void;
}

const HEALTH_COLOR: Record<Forecast["outlook"], string> = {
  comfortable: "var(--ok)",
  tight: "var(--warn)",
  low: "var(--low)",
};

export function QuickView({
  forecast,
  transactions,
  today,
  source,
  onOpenFuture,
  onOpenWhatsNext,
  onOpenSettings,
  onSelectEvent,
}: Props) {
  const coming = listUpcoming(forecast, 3);
  const stats = deriveGlanceStats(forecast, transactions, today);
  const [monthView, setMonthView] = useState<"month" | "day">("month");

  const dayOfMonth = Math.max(1, new Date(today + "T00:00:00").getDate());
  const spentPerDay = Math.round(stats.spentThisMonth / dayOfMonth);
  const typicalPerDay = forecast.assumptions.avgDailySpend;
  const overspending = stats.spentPct > 1;

  return (
    <div className="popover-inner">
      <div className="pop-head">
        <div className="brand">
          <span className="logo"><HorizonMark size={16} /></span>
          Horizon
        </div>
        <div className="actions">
          <button className="icon-btn" onClick={onOpenSettings} aria-label="Settings">
            <Gear size={15} />
          </button>
        </div>
      </div>

      {/* Tiny-icon tab strip (reference-style quick nav) */}
      <div className="tabstrip">
        <button className="tb active" aria-label="Balance"><Wallet size={15} /></button>
        <button className="tb" onClick={onOpenFuture} aria-label="Future"><Sparkle size={13} /></button>
        <button className="tb" onClick={onOpenWhatsNext} aria-label="Radar"><Radar size={15} /></button>
        <button className="tb" onClick={onOpenFuture} aria-label="Scenarios"><Bolt size={14} /></button>
        <button className="tb grow" onClick={onOpenSettings} aria-label="Settings"><Gear size={15} /></button>
      </div>

      <span className="label">Available balance</span>
      <motion.div layoutId="hero-balance" className="balance-hero num">
        {money(forecast.startBalance)}
      </motion.div>
      <div className={`outlook ${forecast.outlook}`}>
        <span className="dot" />
        {OUTLOOK_LABEL[forecast.outlook]}
      </div>

      {/* Ring gauges */}
      <div className="gauge-row">
        <Gauge
          value={stats.bufferPct}
          center={`${Math.round(stats.bufferPct * 100)}%`}
          label="Buffer"
          sub={OUTLOOK_LABEL[forecast.outlook]}
          color={HEALTH_COLOR[forecast.outlook]}
        />
        <Gauge
          value={stats.payCyclePct}
          center={stats.daysToPayday == null ? "-" : `${stats.daysToPayday}d`}
          label="Payday"
          sub="until income"
          color="var(--in)"
        />
        <Gauge
          value={stats.spentPct}
          center={`${Math.round(stats.spentPct * 100)}%`}
          label="Spent"
          sub="of typical"
          color={stats.spentPct > 0.9 ? "var(--out)" : "var(--forecast)"}
        />
      </div>

      {/* This month, with a daily / monthly toggle */}
      <div className="card month-card">
        <div className="fc-head">
          <span className="label">This month</span>
          <div className="seg-mini">
            <button className={monthView === "month" ? "on" : ""} onClick={() => setMonthView("month")}>Month</button>
            <button className={monthView === "day" ? "on" : ""} onClick={() => setMonthView("day")}>Day</button>
          </div>
        </div>
        {monthView === "month" ? (
          <>
            <div className="month-fig">
              <span className="num mf-amt">{money(stats.spentThisMonth)}</span>
              <span className="mf-sub">of ~{money(stats.typicalMonthly)} typical</span>
            </div>
            <div className="mbar">
              <i className={overspending ? "over" : ""} style={{ width: `${Math.min(100, Math.round(stats.spentPct * 100))}%` }} />
            </div>
          </>
        ) : (
          <div className="month-fig">
            <span className="num mf-amt">{money(spentPerDay)}<span className="mf-per">/day</span></span>
            <span className="mf-sub">vs ~{money(typicalPerDay)}/day typical</span>
          </div>
        )}
      </div>

      <div className="card future-card">
        <div className="fc-head">
          <span className="label"><Sparkle size={12} /> Future balance</span>
          <span className="when" style={{ fontSize: 10, color: "var(--ink-faint)" }}>
            {forecast.horizonDays} days
          </span>
        </div>

        <ForecastGraph forecast={forecast} today={today} height={96} />

        <div className="future-figure">
          <span className="amt num">{money(forecast.projected)}</span>
          <span className="when">In {forecast.horizonDays} days</span>
        </div>

        <button className="btn" style={{ marginTop: 14 }} onClick={onOpenFuture}>
          <span className="accent"><Sparkle size={13} /></span>
          See full future
          <ChevronRight size={14} />
        </button>
      </div>

      <div className="section-gap">
        <span className="label">Coming up</span>
        <div className="list">
          {coming.map((e) => (
            <div className="row" key={e.id} onClick={() => onSelectEvent(e)}>
              <span className="glyph"><CategoryIcon category={e.category} /></span>
              <div className="body">
                <div className="name">{e.label}</div>
                <div className="meta">
                  {relativeDay(e.date, today)}
                  {e.kind === "recurring" && <span className="tag recurring">Recurring</span>}
                </div>
              </div>
              <span className={`amt ${e.direction}`}>{signedMoney(e.amount)}</span>
            </div>
          ))}
        </div>
      </div>

      <div className="btn-row">
        <button className="btn ghost" onClick={onOpenWhatsNext}>
          <Radar size={14} /> What&apos;s happening next?
        </button>
      </div>

      <div className="source-flag">{source}</div>
    </div>
  );
}
