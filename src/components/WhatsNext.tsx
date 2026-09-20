import { motion } from "framer-motion";
import type { Forecast, UpcomingEvent } from "../types";
import { listUpcoming } from "../services/forecastService";
import { relativeDay, signedMoney, daysBetween } from "../lib/format";
import { CategoryIcon, ChevronLeft, ArrowDown, ArrowUp, Radar } from "./icons";

interface Props {
  forecast: Forecast;
  today: string;
  onBack: () => void;
  onSelectEvent: (e: UpcomingEvent) => void;
}

/** A compact 7-day radar of upcoming money movements. */
export function WhatsNext({ forecast, today, onBack, onSelectEvent }: Props) {
  const events = listUpcoming(forecast, 20).filter((e) => daysBetween(today, e.date) <= 7);

  return (
    <div className="popover-inner">
      <div className="pop-head">
        <button className="back-btn" onClick={onBack}>
          <ChevronLeft size={15} /> Balance
        </button>
        <div className="brand" style={{ marginLeft: "auto", fontSize: 12, color: "var(--ink-dim)" }}>
          <Radar size={14} /> Next 7 days
        </div>
      </div>

      <span className="label">Financial radar</span>

      <div className="list" style={{ marginTop: 12 }}>
        {events.length === 0 && (
          <div style={{ fontSize: 13, color: "var(--ink-faint)", padding: "18px 0" }}>
            Nothing scheduled in the next 7 days. Quiet week ahead.
          </div>
        )}
        {events.map((e, i) => (
          <motion.div
            key={e.id}
            className="row"
            onClick={() => onSelectEvent(e)}
            initial={{ opacity: 0, x: -8 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ delay: i * 0.05 }}
          >
            <span className="glyph" style={{ color: e.direction === "in" ? "var(--in)" : "var(--out)" }}>
              {e.direction === "in" ? <ArrowUp size={15} /> : <ArrowDown size={15} />}
            </span>
            <div className="body">
              <div className="name">{e.label}</div>
              <div className="meta">
                {relativeDay(e.date, today)}
                {e.kind === "recurring" && <span className="tag recurring">Recurring</span>}
              </div>
            </div>
            <span style={{ display: "flex", alignItems: "center", gap: 8 }}>
              <span className={`amt ${e.direction}`}>{signedMoney(e.amount)}</span>
              <span style={{ color: "var(--ink-ghost)" }}>
                <CategoryIcon category={e.category} size={14} />
              </span>
            </span>
          </motion.div>
        ))}
      </div>
    </div>
  );
}
