import type { Forecast } from "../types";
import { money } from "../lib/format";

interface Props {
  forecast: Forecast | null;
  open: boolean;
  onToggle: () => void;
}

/** A faux macOS menu bar. The balance pill on the right is the whole product. */
export function MenuBar({ forecast, open, onToggle }: Props) {
  const time = new Date().toLocaleTimeString("en-ZA", { hour: "numeric", minute: "2-digit" });
  const date = new Date().toLocaleDateString("en-ZA", { weekday: "short", day: "numeric", month: "short" });

  return (
    <div className="menubar">
      <span className="spacer"> Horizon</span>
      <span className="sys" style={{ opacity: 0.55 }}>File</span>
      <span className="sys" style={{ opacity: 0.55 }}>View</span>
      <span className="sys" style={{ opacity: 0.55 }}>Window</span>

      <button
        className={`menu-pill ${open ? "active" : ""}`}
        onClick={onToggle}
        title="Horizon  (⌘⇧B)"
      >
        {forecast && <span className={`menu-dot ${forecast.outlook}`} />}
        {forecast ? money(forecast.startBalance) : "R-"}
      </button>

      <span className="sys" style={{ opacity: 0.6 }}>{date}</span>
      <span className="sys" style={{ opacity: 0.85, fontWeight: 600, color: "var(--ink)" }}>{time}</span>
    </div>
  );
}
