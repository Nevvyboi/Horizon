import { motion } from "framer-motion";

interface Props {
  /** 0..1 fill. */
  value: number;
  /** Big centre text, e.g. "65%" or "5d". */
  center: string;
  label: string;
  sub?: string;
  color?: string;
  size?: number;
}

/** A compact circular progress ring, the signature meter from the reference. */
export function Gauge({ value, center, label, sub, color = "var(--forecast)", size = 74 }: Props) {
  const stroke = 5;
  const r = (size - stroke) / 2;
  const c = 2 * Math.PI * r;
  const dash = Math.max(0, Math.min(1, value)) * c;

  return (
    <div className="gauge">
      <div className="gauge-ring" style={{ width: size, height: size }}>
        <svg width={size} height={size}>
          <circle
            cx={size / 2}
            cy={size / 2}
            r={r}
            fill="none"
            stroke="var(--glass-inset)"
            strokeWidth={stroke}
          />
          <motion.circle
            cx={size / 2}
            cy={size / 2}
            r={r}
            fill="none"
            stroke={color}
            strokeWidth={stroke}
            strokeLinecap="round"
            transform={`rotate(-90 ${size / 2} ${size / 2})`}
            strokeDasharray={`${dash} ${c}`}
            initial={{ strokeDasharray: `0 ${c}` }}
            animate={{ strokeDasharray: `${dash} ${c}` }}
            transition={{ duration: 0.9, ease: [0.22, 0.8, 0.28, 1] }}
            style={{ filter: `drop-shadow(0 0 5px ${color})` }}
          />
        </svg>
        <div className="gauge-center">
          <span className="gauge-label">{label}</span>
          <span className="gauge-val num">{center}</span>
        </div>
      </div>
      {sub && <div className="gauge-sub">{sub}</div>}
    </div>
  );
}
