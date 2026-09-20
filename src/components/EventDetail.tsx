import type { UpcomingEvent } from "../types";
import { moneyCents, shortDate } from "../lib/format";
import { CategoryIcon, ChevronLeft } from "./icons";

function confidenceWord(c: number): string {
  if (c >= 0.85) return "High";
  if (c >= 0.65) return "Medium";
  return "Low";
}

interface Props {
  event: UpcomingEvent;
  note: string;
  onNote: (v: string) => void;
  onBack: () => void;
}

export function EventDetail({ event, note, onNote, onBack }: Props) {
  return (
    <div className="popover-inner">
      <div className="pop-head">
        <button className="back-btn" onClick={onBack}>
          <ChevronLeft size={15} /> Back
        </button>
      </div>

      <div style={{ display: "flex", alignItems: "center", gap: 12, marginBottom: 4 }}>
        <span className="glyph" style={{ width: 40, height: 40, borderRadius: 12 }}>
          <CategoryIcon category={event.category} size={19} />
        </span>
        <div>
          <div style={{ fontSize: 16, fontWeight: 600 }}>{event.label}</div>
          <div style={{ fontSize: 12, color: "var(--ink-faint)", textTransform: "capitalize" }}>
            {event.category.replace("-", " ")}
          </div>
        </div>
      </div>

      <div className="detail-amt num" style={{ color: event.direction === "in" ? "var(--in)" : "var(--out)" }}>
        {event.direction === "in" ? "+" : "−"}
        {moneyCents(Math.abs(event.amount))}
      </div>
      <div style={{ fontSize: 12.5, color: "var(--ink-dim)" }}>{shortDate(event.date)}</div>

      <div className="detail-meta">
        <div className="detail-line">
          <span className="dl-k">Type</span>
          <span>{event.kind === "recurring" ? "Recurring payment" : "Expected once-off"}</span>
        </div>
        {event.kind === "recurring" && (
          <div className="detail-line">
            <span className="dl-k">Confidence</span>
            <span style={{ display: "flex", alignItems: "center", gap: 8 }}>
              {confidenceWord(event.confidence)}
              <span className="confidence-bar"><i style={{ width: `${Math.round(event.confidence * 100)}%` }} /></span>
            </span>
          </div>
        )}
        <div className="detail-line">
          <span className="dl-k">Direction</span>
          <span>{event.direction === "in" ? "Money in" : "Money out"}</span>
        </div>
      </div>

      <div className="note-field">
        <span className="label" style={{ display: "block", marginBottom: 8 }}>Note</span>
        <textarea
          placeholder="Add a note, e.g. Client meeting"
          value={note}
          onChange={(e) => onNote(e.target.value)}
        />
      </div>
    </div>
  );
}
