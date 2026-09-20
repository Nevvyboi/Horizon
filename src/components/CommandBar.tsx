import { useEffect, useMemo, useRef, useState } from "react";
import { motion } from "framer-motion";
import type { Forecast, Scenario } from "../types";
import { money, shortDate } from "../lib/format";
import { listUpcoming } from "../services/forecastService";
import { Sparkle } from "./icons";

interface Props {
  base: Forecast;
  today: string;
  forecastWith: (s?: Scenario) => Forecast | null;
  onClose: () => void;
}

const SUGGESTIONS = [
  "What's my balance?",
  "What will I have on payday?",
  "What's coming up?",
  "Why will my balance drop?",
  "Can I spend R2,000 today?",
];

interface Answer {
  text: string;
  big?: string;
}

export function CommandBar({ base, today, forecastWith, onClose }: Props) {
  const [q, setQ] = useState("");
  const [answer, setAnswer] = useState<Answer | null>(null);
  const [sel, setSel] = useState(0);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    inputRef.current?.focus();
  }, []);

  const filtered = useMemo(
    () => SUGGESTIONS.filter((s) => s.toLowerCase().includes(q.toLowerCase().trim())),
    [q],
  );

  function answerFor(query: string): Answer {
    const s = query.toLowerCase();

    // afford / spend
    const amt = s.match(/(?:spend|afford|buy).*?r?\s?(\d[\d,]*)\s?(k)?/i);
    if (amt) {
      const value = Math.round(parseFloat(amt[1].replace(/,/g, "")) * (amt[2] ? 1000 : 1));
      const scenario = forecastWith({
        id: "cmd",
        label: query,
        extraEvents: [{ id: "cmd-buy", date: today, label: "This purchase", amount: -value, direction: "out", category: "other", kind: "known", confidence: 1 }],
      });
      const low = scenario?.lowest.balance ?? base.lowest.balance;
      return {
        big: money(base.startBalance - value),
        text: `After spending ${money(value)} today, your projected minimum balance drops to ${money(low)} (from ${money(base.lowest.balance)}). ${low > 3000 ? "You would stay above a healthy buffer." : "That leaves little room before your next income."}`,
      };
    }

    if (/payday|salary|paid|income/.test(s)) {
      const income = listUpcoming(base, 20).find((e) => e.direction === "in");
      if (income) {
        const pt = base.points.find((p) => p.date === income.date);
        return {
          big: money(pt?.balance ?? base.startBalance),
          text: `Your next expected income is ${money(income.amount)} on ${shortDate(income.date)} (${income.label}). Your balance should be around ${money(pt?.balance ?? 0)} just after it lands.`,
        };
      }
      return { text: "No expected income was detected in your recent activity." };
    }

    if (/coming up|upcoming|next|scheduled/.test(s)) {
      const items = listUpcoming(base, 3);
      return {
        text: `Coming up: ${items.map((e) => `${e.label} ${money(e.amount)} on ${shortDate(e.date)}`).join("; ")}.`,
      };
    }

    if (/why|drop|lowest|risk|tight/.test(s)) {
      const lowPt = base.points.find((p) => p.dayOffset === base.lowest.dayOffset);
      const causes = lowPt?.events.filter((e) => e.kind !== "estimated-spend").map((e) => e.label) ?? [];
      return {
        big: money(base.lowest.balance),
        text: `Your balance is projected to bottom out on ${shortDate(base.lowest.date)}${causes.length ? `, mainly due to ${causes.join(" and ")}` : ""}. It recovers with your next expected income.`,
      };
    }

    // default: balance
    return {
      big: money(base.startBalance),
      text: `Your available balance is ${money(base.startBalance)}. Projected to be ${money(base.projected)} in ${base.horizonDays} days. Outlook: ${base.outlook}.`,
    };
  }

  function run(query: string) {
    if (!query.trim()) return;
    setAnswer(answerFor(query));
  }

  return (
    <div className="cmd-scrim" onClick={onClose}>
      <motion.div
        className="cmd"
        onClick={(e) => e.stopPropagation()}
        initial={{ opacity: 0, y: -12, scale: 0.98 }}
        animate={{ opacity: 1, y: 0, scale: 1 }}
        exit={{ opacity: 0, y: -12, scale: 0.98 }}
        transition={{ duration: 0.2, ease: [0.22, 0.8, 0.28, 1] }}
      >
        <input
          ref={inputRef}
          value={q}
          placeholder="Ask your money…"
          onChange={(e) => {
            setQ(e.target.value);
            setAnswer(null);
            setSel(0);
          }}
          onKeyDown={(e) => {
            if (e.key === "Enter") run(filtered[sel] ?? q);
            if (e.key === "ArrowDown") setSel((s) => Math.min(filtered.length - 1, s + 1));
            if (e.key === "ArrowUp") setSel((s) => Math.max(0, s - 1));
            if (e.key === "Escape") onClose();
          }}
        />

        {!answer && (
          <div className="cmd-list">
            {filtered.map((s, i) => (
              <div
                key={s}
                className={`cmd-opt ${i === sel ? "sel" : ""}`}
                onMouseEnter={() => setSel(i)}
                onClick={() => run(s)}
              >
                <Sparkle size={12} />
                {s}
                <span className="kbd">↵</span>
              </div>
            ))}
          </div>
        )}

        {answer && (
          <div className="cmd-answer">
            {answer.big && <span className="big num">{answer.big}</span>}
            {answer.text}
          </div>
        )}
      </motion.div>
    </div>
  );
}
