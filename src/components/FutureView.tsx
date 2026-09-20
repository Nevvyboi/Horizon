import { useMemo, useState } from "react";
import { AnimatePresence, motion } from "framer-motion";
import type { Forecast, Scenario, UpcomingEvent } from "../types";
import { money, signedMoney, shortDate } from "../lib/format";
import { AnimatedNumber } from "./AnimatedNumber";
import { ForecastGraph } from "./ForecastGraph";
import { Timeline } from "./Timeline";
import { ChevronLeft, Question, Bolt, Wallet, Check, Warning, Sparkle } from "./icons";

const OUTLOOK_LABEL: Record<Forecast["outlook"], string> = {
  comfortable: "Comfortable",
  tight: "Getting tight",
  low: "Low buffer",
};

type Mode = "overview" | "explain" | "scenario" | "afford";

interface Props {
  base: Forecast;
  today: string;
  forecastWith: (s?: Scenario) => Forecast | null;
  onBack: () => void;
  onSelectEvent: (e: UpcomingEvent) => void;
}

const SCENARIOS: Scenario[] = [
  { id: "spend", label: "Spend R3,000 today", extraEvents: [oneOff("Impulse spend", -3000)] },
  { id: "late", label: "Salary arrives 3 days late", incomeShiftDays: 3 },
  { id: "save", label: "Save R2,000 this month", extraEvents: [oneOff("Move to savings", -2000)] },
  { id: "cutback", label: "Cut spending 30%", spendMultiplier: 0.7 },
  { id: "cancel", label: "Cancel Netflix", cancelRecurring: "netflix" },
];

function oneOff(label: string, amount: number): UpcomingEvent {
  return {
    id: `oneoff-${label}`,
    date: "",
    label,
    amount,
    direction: amount >= 0 ? "in" : "out",
    category: amount >= 0 ? "income" : "other",
    kind: "known",
    confidence: 1,
  };
}

export function FutureView({ base, today, forecastWith, onBack, onSelectEvent }: Props) {
  const [mode, setMode] = useState<Mode>("overview");
  const [scenario, setScenario] = useState<Scenario | null>(null);
  const [afford, setAfford] = useState("");

  // date the one-off events to "today" now that we know it
  const activeScenario = useMemo<Scenario | null>(() => {
    if (mode === "afford") {
      const amt = parseAmount(afford);
      if (!amt) return null;
      return { id: "afford", label: afford, extraEvents: [{ ...oneOff("This purchase", -amt), date: today }] };
    }
    if (scenario) {
      return {
        ...scenario,
        extraEvents: scenario.extraEvents?.map((e) => ({ ...e, date: today })),
      };
    }
    return null;
  }, [mode, scenario, afford, today]);

  const current = forecastWith(activeScenario ?? undefined) ?? base;
  const showGhost = activeScenario != null;

  return (
    <div className="popover-inner">
      <div className="pop-head">
        <button className="back-btn" onClick={onBack}>
          <ChevronLeft size={15} /> Balance
        </button>
        <div className="actions" style={{ gap: 2 }}>
          <SegBtn active={mode === "explain"} onClick={() => setMode(mode === "explain" ? "overview" : "explain")} title="Why?"><Question size={13} /></SegBtn>
          <SegBtn active={mode === "scenario"} onClick={() => { setMode(mode === "scenario" ? "overview" : "scenario"); setScenario(null); }} title="What if?"><Bolt size={13} /></SegBtn>
          <SegBtn active={mode === "afford"} onClick={() => setMode(mode === "afford" ? "overview" : "afford")} title="Can I afford?"><Wallet size={13} /></SegBtn>
        </div>
      </div>

      {/* The morph ladder */}
      <span className="label">{showGhost ? "Scenario forecast" : "Future balance"}</span>
      <Ladder forecast={current} today={today} />

      {/* Graph with ghost of the base plan when a scenario is on */}
      <div style={{ marginTop: 8 }}>
        <ForecastGraph
          forecast={current}
          today={today}
          height={132}
          ghost={showGhost ? base : undefined}
          animateKey={activeScenario?.id ?? "base"}
        />
      </div>

      {/* Outlook */}
      <div className="assumptions" style={{ marginTop: 16 }}>
        <span className="label">Financial outlook</span>
        <div className={`outlook ${current.outlook}`} style={{ fontSize: 15, marginBottom: 6 }}>
          <span className="dot" />
          {OUTLOOK_LABEL[current.outlook]}
        </div>
        <div style={{ fontSize: 12.5, color: "var(--ink-dim)", lineHeight: 1.5 }}>
          Your projected minimum balance is{" "}
          <strong style={{ color: "var(--ink)" }}>{money(current.lowest.balance)}</strong> on{" "}
          {shortDate(current.lowest.date)}, before your next expected income.
        </div>
      </div>

      <AnimatePresence mode="wait">
        {mode === "explain" && (
          <Panel key="explain">
            <ExplainPanel forecast={current} />
          </Panel>
        )}
        {mode === "scenario" && (
          <Panel key="scenario">
            <ScenarioPanel
              base={base}
              scenario={current}
              active={scenario}
              onPick={(s) => setScenario(scenario?.id === s.id ? null : s)}
            />
          </Panel>
        )}
        {mode === "afford" && (
          <Panel key="afford">
            <AffordPanel base={base} scenario={current} value={afford} onChange={setAfford} />
          </Panel>
        )}
      </AnimatePresence>

      {/* Timeline */}
      <div className="section-gap">
        <span className="label">Timeline</span>
        <Timeline forecast={current} today={today} limit={6} onSelect={onSelectEvent} />
      </div>

      <div className="footnote">
        <Sparkle size={11} />
        <span>
          Projected from recent activity. These are estimates, not guaranteed outcomes.
        </span>
      </div>
    </div>
  );
}

function Ladder({ forecast, today }: { forecast: Forecast; today: string }) {
  void today;
  const marks = [0, 7, 14, forecast.horizonDays].filter((v, i, a) => a.indexOf(v) === i);
  const steps = marks.map((d) => {
    const p = forecast.points.find((x) => x.dayOffset === d) ?? forecast.points[forecast.points.length - 1];
    return { when: d === 0 ? "TODAY" : `${d} DAYS`, balance: p.balance, low: p.dayOffset === forecast.lowest.dayOffset };
  });

  return (
    <div className="ladder">
      {steps.map((s, i) => (
        <div key={s.when}>
          <motion.div
            className="ladder-step"
            initial={{ opacity: 0, y: 6 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: i * 0.06 }}
          >
            <span className="ld-when">{s.when}</span>
            <AnimatedNumber value={s.balance} className="ld-amt num" />
          </motion.div>
          {i < steps.length - 1 && <div className="ladder-arrow">↓</div>}
        </div>
      ))}
    </div>
  );
}

function Panel({ children }: { children: React.ReactNode }) {
  return (
    <motion.div
      initial={{ opacity: 0, height: 0 }}
      animate={{ opacity: 1, height: "auto" }}
      exit={{ opacity: 0, height: 0 }}
      transition={{ duration: 0.28, ease: [0.22, 0.8, 0.28, 1] }}
      style={{ overflow: "hidden" }}
    >
      {children}
    </motion.div>
  );
}

function SegBtn({ active, onClick, title, children }: { active: boolean; onClick: () => void; title: string; children: React.ReactNode }) {
  return (
    <button className={`icon-btn ${active ? "active" : ""}`} onClick={onClick} title={title} aria-label={title}>
      {children}
    </button>
  );
}

/* ---- Explain -------------------------------------------------------------- */

function ExplainPanel({ forecast }: { forecast: Forecast }) {
  const b = forecast.breakdown;
  return (
    <div className="assumptions" style={{ marginTop: 14 }}>
      <span className="label">Why {money(b.projected)}?</span>
      <div className="breakdown">
        <BdRow label="Starting balance" val={money(b.startBalance)} />
        <BdRow label="Expected income" val={signedMoney(b.expectedIncome)} color="var(--in)" />
        <BdRow label="Recurring payments" val={signedMoney(b.recurringPayments)} color="var(--out)" />
        <BdRow label="Typical spending" val={signedMoney(b.typicalSpending)} color="var(--out)" />
        <div className="bd-row total">
          <span className="bd-label">Projected</span>
          <span className="bd-val num">{money(b.projected)}</span>
        </div>
      </div>
      <div style={{ marginTop: 12 }}>
        <span className="label">Based on</span>
        {forecast.assumptions.notes.map((n) => (
          <div className="assump-item" key={n}>
            <span className="check"><Check size={12} /></span>
            {n}
          </div>
        ))}
      </div>
    </div>
  );
}

function BdRow({ label, val, color }: { label: string; val: string; color?: string }) {
  return (
    <div className="bd-row">
      <span className="bd-label">{label}</span>
      <span className="bd-val num" style={{ color }}>{val}</span>
    </div>
  );
}

/* ---- Scenario ------------------------------------------------------------- */

function ScenarioPanel({ base, scenario, active, onPick }: {
  base: Forecast;
  scenario: Forecast;
  active: Scenario | null;
  onPick: (s: Scenario) => void;
}) {
  // Compare the projected MINIMUM balance, not the end-of-horizon number.
  // The minimum is what the app is really about ("your lowest buffer"), and it
  // responds to every scenario, including timing changes like a late salary
  // that leave the 30-day endpoint unchanged.
  const delta = scenario.lowest.balance - base.lowest.balance;
  const endDelta = scenario.projected - base.projected;
  return (
    <div className="assumptions" style={{ marginTop: 14 }}>
      <span className="label">What if?</span>
      <div className="chips">
        {SCENARIOS.map((s) => (
          <button key={s.id} className={`chip ${active?.id === s.id ? "active" : ""}`} onClick={() => onPick(s)}>
            {s.label}
          </button>
        ))}
      </div>
      {active && (
        <>
          <div style={{ fontSize: 10.5, letterSpacing: "0.08em", textTransform: "uppercase", color: "var(--ink-faint)", margin: "12px 0 2px" }}>
            Projected minimum balance
          </div>
          <div className="compare">
            <div className="col">
              <div className="c-label">Current plan</div>
              <div className="c-val num">{money(base.lowest.balance)}</div>
            </div>
            <div className="arrow">→</div>
            <div className="col scenario">
              <div className="c-label">Scenario</div>
              <AnimatedNumber value={scenario.lowest.balance} className="c-val num" />
            </div>
          </div>
        </>
      )}
      {active && (
        <div className={`callout ${delta >= 0 ? "ok" : ""}`}>
          <span className="co-icon">{delta >= 0 ? <Check size={14} /> : <Warning size={14} />}</span>
          <span>
            This {delta >= 0 ? "lifts" : "lowers"} your projected minimum by{" "}
            <strong style={{ color: "var(--ink)" }}>{money(Math.abs(delta))}</strong>
            {Math.abs(endDelta) > 1 && (
              <> and your 30-day balance ends at {money(scenario.projected)}</>
            )}
            .
          </span>
        </div>
      )}
    </div>
  );
}

/* ---- Afford --------------------------------------------------------------- */

function AffordPanel({ base, scenario, value, onChange }: {
  base: Forecast;
  scenario: Forecast;
  value: string;
  onChange: (v: string) => void;
}) {
  const amt = parseAmount(value);
  const lowDelta = scenario.lowest.balance - base.lowest.balance;
  return (
    <div className="assumptions" style={{ marginTop: 14 }}>
      <span className="label">Can I afford this?</span>
      <div className="note-field" style={{ marginTop: 8 }}>
        <input
          autoFocus
          placeholder="e.g. R5,000 headphones"
          value={value}
          onChange={(e) => onChange(e.target.value)}
          style={{
            width: "100%",
            borderRadius: "var(--r-sm)",
            border: "1px solid var(--border)",
            background: "var(--glass-inset)",
            color: "var(--ink)",
            fontFamily: "var(--font)",
            fontSize: 14,
            padding: "11px 13px",
            outline: "none",
          }}
        />
      </div>
      {amt ? (
        <>
          <div className="compare" style={{ marginTop: 12 }}>
            <div className="col">
              <div className="c-label">Current</div>
              <div className="c-val num">{money(base.startBalance)}</div>
            </div>
            <div className="arrow">→</div>
            <div className="col scenario">
              <div className="c-label">After purchase</div>
              <div className="c-val num">{money(base.startBalance - amt)}</div>
            </div>
          </div>
          <div className="bd-row" style={{ marginTop: 6 }}>
            <span className="bd-label">Projected lowest balance</span>
            <span className="bd-val num" style={{ color: scenario.lowest.balance < 2000 ? "var(--low)" : "var(--ink)" }}>
              {money(scenario.lowest.balance)}
            </span>
          </div>
          <div className={`callout ${scenario.lowest.balance > 3000 ? "ok" : ""}`}>
            <span className="co-icon">{scenario.lowest.balance > 3000 ? <Check size={14} /> : <Warning size={14} />}</span>
            <span>
              This would lower your projected minimum by {money(Math.abs(lowDelta))} to{" "}
              <strong style={{ color: "var(--ink)" }}>{money(scenario.lowest.balance)}</strong>.{" "}
              {scenario.lowest.balance > 3000
                ? "You would stay above a healthy buffer."
                : "That leaves little room before your next income."}
            </span>
          </div>
        </>
      ) : (
        <div style={{ fontSize: 12, color: "var(--ink-faint)", marginTop: 8 }}>
          Type an amount to simulate the purchase against your forecast.
        </div>
      )}
    </div>
  );
}

function parseAmount(input: string): number | null {
  const m = input.replace(/[, ]/g, "").match(/r?(\d+(?:\.\d+)?)k?/i);
  if (!m) return null;
  let n = parseFloat(m[1]);
  if (/k/i.test(input)) n *= 1000;
  return n > 0 ? Math.round(n) : null;
}
