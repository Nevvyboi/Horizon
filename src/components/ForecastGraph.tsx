import { useMemo, useRef, useState } from "react";
import { motion } from "framer-motion";
import type { Forecast, ForecastPoint } from "../types";
import { money, signedMoney, relativeDay } from "../lib/format";

interface Props {
  forecast: Forecast;
  today: string;
  height?: number;
  /** An optional second curve drawn faintly behind (the base plan in scenarios). */
  ghost?: Forecast;
  animateKey?: string | number;
}

/**
 * A minimalist "financial trajectory": a smooth curve with a gradient fill, a
 * glowing point at today, small markers on event days, and a hover readout.
 * Not a stock chart, on purpose.
 */
export function ForecastGraph({ forecast, today, height = 128, ghost, animateKey }: Props) {
  const wrapRef = useRef<HTMLDivElement>(null);
  const [hover, setHover] = useState<number | null>(null);
  const W = 300;
  const H = height;
  const padY = 18;
  const padX = 6;

  const { path, area, coords, ghostPath, yFor, xFor, lowIndex } = useMemo(() => {
    const pts = forecast.points;
    const all = ghost ? [...pts, ...ghost.points] : pts;
    const balances = all.map((p) => p.balance);
    const min = Math.min(...balances);
    const max = Math.max(...balances);
    const span = Math.max(1, max - min);

    const xFor = (i: number, n: number) => padX + (i / (n - 1)) * (W - padX * 2);
    const yFor = (b: number) => padY + (1 - (b - min) / span) * (H - padY * 2);

    const toCurve = (arr: ForecastPoint[]) => {
      const c = arr.map((p, i) => ({ x: xFor(i, arr.length), y: yFor(p.balance) }));
      let d = `M ${c[0].x} ${c[0].y}`;
      for (let i = 1; i < c.length; i++) {
        const p0 = c[i - 1];
        const p1 = c[i];
        const mx = (p0.x + p1.x) / 2;
        d += ` C ${mx} ${p0.y} ${mx} ${p1.y} ${p1.x} ${p1.y}`;
      }
      return { d, c };
    };

    const main = toCurve(pts);
    const g = ghost ? toCurve(ghost.points) : null;
    const areaD = `${main.d} L ${main.c[main.c.length - 1].x} ${H - padY} L ${main.c[0].x} ${H - padY} Z`;

    let lowIndex = 0;
    pts.forEach((p, i) => {
      if (p.balance < pts[lowIndex].balance) lowIndex = i;
    });

    return {
      path: main.d,
      area: areaD,
      coords: main.c,
      ghostPath: g?.d ?? null,
      yFor,
      xFor: (i: number) => xFor(i, pts.length),
      lowIndex,
    };
  }, [forecast, ghost, H]);

  const pts = forecast.points;
  const eventIdx = pts
    .map((p, i) => ({ i, has: p.events.some((e) => e.kind !== "estimated-spend") }))
    .filter((x) => x.has)
    .map((x) => x.i);

  function onMove(e: React.MouseEvent) {
    const rect = wrapRef.current?.getBoundingClientRect();
    if (!rect) return;
    const rel = (e.clientX - rect.left) / rect.width;
    const idx = Math.round(rel * (pts.length - 1));
    setHover(Math.max(0, Math.min(pts.length - 1, idx)));
  }

  const hp = hover != null ? pts[hover] : null;
  const hx = hover != null ? (xFor(hover) / W) * 100 : 0;

  return (
    <div
      className="graph-wrap"
      ref={wrapRef}
      onMouseMove={onMove}
      onMouseLeave={() => setHover(null)}
    >
      <svg className="graph-svg" viewBox={`0 0 ${W} ${H}`} preserveAspectRatio="none">
        <defs>
          <linearGradient id="fillGrad" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="rgba(200,138,74,0.30)" />
            <stop offset="100%" stopColor="rgba(200,138,74,0)" />
          </linearGradient>
          <linearGradient id="lineGrad" x1="0" y1="0" x2="1" y2="0">
            <stop offset="0%" stopColor="#c88a4a" />
            <stop offset="100%" stopColor="#9fb0c2" />
          </linearGradient>
        </defs>

        {ghostPath && (
          <path d={ghostPath} fill="none" stroke="rgba(244,244,242,0.22)" strokeWidth={1.4} strokeDasharray="3 4" />
        )}

        <motion.path
          key={`area-${animateKey}`}
          d={area}
          fill="url(#fillGrad)"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 0.5, delay: 0.15 }}
        />
        <motion.path
          key={`line-${animateKey}`}
          d={path}
          fill="none"
          stroke="url(#lineGrad)"
          strokeWidth={2.2}
          strokeLinecap="round"
          initial={{ pathLength: 0 }}
          animate={{ pathLength: 1 }}
          transition={{ duration: 0.9, ease: [0.22, 0.8, 0.28, 1] }}
        />

        {/* event markers */}
        {eventIdx.map((i) => (
          <circle key={i} cx={xFor(i)} cy={yFor(pts[i].balance)} r={2.4} fill="rgba(244,244,242,0.55)" />
        ))}

        {/* lowest point */}
        <circle cx={xFor(lowIndex)} cy={yFor(pts[lowIndex].balance)} r={3.4} fill="#e59a8f" />

        {/* glowing today point */}
        <motion.circle
          cx={coords[0].x}
          cy={coords[0].y}
          r={4}
          fill="#f4f4f2"
          initial={{ scale: 0 }}
          animate={{ scale: 1 }}
          transition={{ delay: 0.3, type: "spring", stiffness: 260, damping: 16 }}
        />
        <circle cx={coords[0].x} cy={coords[0].y} r={8} fill="none" stroke="rgba(244,244,242,0.25)" strokeWidth={1}>
          <animate attributeName="r" values="6;11;6" dur="2.4s" repeatCount="indefinite" />
          <animate attributeName="opacity" values="0.5;0;0.5" dur="2.4s" repeatCount="indefinite" />
        </circle>

        {hover != null && (
          <line x1={xFor(hover)} y1={padY - 6} x2={xFor(hover)} y2={H - padY} stroke="rgba(244,244,242,0.2)" strokeWidth={1} />
        )}
        {hp && (
          <circle cx={xFor(hover!)} cy={yFor(hp.balance)} r={3.4} fill="#c88a4a" />
        )}
      </svg>

      {hp && (
        <div
          className="graph-hover-card"
          style={{
            left: `clamp(0px, ${hx}% - 75px, calc(100% - 150px))`,
            top: 0,
          }}
        >
          <div className="gh-when">{relativeDay(hp.date, today)}</div>
          <div className="gh-bal num">{money(hp.balance)}</div>
          {hp.events
            .filter((e) => e.kind !== "estimated-spend")
            .slice(0, 3)
            .map((e) => (
              <div className="gh-ev" key={e.id}>
                <span>{e.label}</span>
                <span style={{ color: e.direction === "in" ? "var(--in)" : "var(--out)" }}>
                  {signedMoney(e.amount)}
                </span>
              </div>
            ))}
          {hover === lowIndex && <div className="gh-low">Lowest expected balance</div>}
        </div>
      )}
    </div>
  );
}
