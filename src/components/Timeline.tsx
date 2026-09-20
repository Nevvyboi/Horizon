import { motion } from "framer-motion";
import type { Forecast, UpcomingEvent } from "../types";
import { listUpcoming } from "../services/forecastService";
import { money, relativeDay, signedMoney } from "../lib/format";

interface Props {
  forecast: Forecast;
  today: string;
  limit?: number;
  onSelect?: (event: UpcomingEvent) => void;
  showBookends?: boolean;
}

/** The interactive vertical timeline of money moving in and out. */
export function Timeline({ forecast, today, limit = 7, onSelect, showBookends = true }: Props) {
  const events = listUpcoming(forecast, limit);

  return (
    <div className="timeline">
      {showBookends && (
        <Item
          index={0}
          when="TODAY"
          nodeClass="today"
          label="Current balance"
          sub="Where you stand right now"
          amt={money(forecast.startBalance)}
          amtColor="var(--ink)"
        />
      )}

      {events.map((e, i) => (
        <Item
          key={e.id}
          index={i + 1}
          when={relativeDay(e.date, today)}
          nodeClass={e.direction}
          label={e.label}
          sub={e.kind === "recurring" ? "Recurring payment" : "Expected"}
          amt={signedMoney(e.amount)}
          amtColor={e.direction === "in" ? "var(--in)" : "var(--out)"}
          onClick={onSelect ? () => onSelect(e) : undefined}
        />
      ))}

      {showBookends && (
        <Item
          index={events.length + 1}
          when={`${forecast.horizonDays} DAYS`}
          nodeClass="projected"
          label="Projected balance"
          sub="Before your next expected income cycle"
          amt={money(forecast.projected)}
          amtColor="var(--forecast)"
          last
        />
      )}
    </div>
  );
}

function Item({
  index,
  when,
  nodeClass,
  label,
  sub,
  amt,
  amtColor,
  onClick,
  last,
}: {
  index: number;
  when: string;
  nodeClass: string;
  label: string;
  sub: string;
  amt: string;
  amtColor: string;
  onClick?: () => void;
  last?: boolean;
}) {
  return (
    <motion.div
      className="tl-item"
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: 0.05 * index, duration: 0.32, ease: [0.22, 0.8, 0.28, 1] }}
    >
      <div className="tl-when">{when}</div>
      <div style={{ display: "grid", gridTemplateColumns: "18px 1fr", gap: 10 }}>
        <div className="tl-rail">
          <div className={`tl-node ${nodeClass}`} />
          {!last && <div className="tl-line" />}
        </div>
        <div
          className="tl-card"
          onClick={onClick}
          style={{ cursor: onClick ? "pointer" : "default" }}
        >
          <div>
            <div className="tc-label">{label}</div>
            <div className="tc-sub">{sub}</div>
          </div>
          <div className="tc-amt" style={{ color: amtColor }}>
            {amt}
          </div>
        </div>
      </div>
    </motion.div>
  );
}
