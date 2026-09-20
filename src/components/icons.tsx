/** Minimal, consistent SVG icons. 1.6px strokes, currentColor. */

import type { Category } from "../types";

type P = { size?: number };
const base = (size = 16) => ({
  width: size,
  height: size,
  viewBox: "0 0 24 24",
  fill: "none",
  stroke: "currentColor",
  strokeWidth: 1.6,
  strokeLinecap: "round" as const,
  strokeLinejoin: "round" as const,
});

/** The Horizon mark: a sun-ring cresting a rolling horizon (cropped icon). */
export const HorizonMark = ({ size = 16 }: P) => (
  <svg {...base(size)}>
    <circle cx="12" cy="10.5" r="4.6" />
    <path d="M3 15.6c4-2 14-2 18 0" />
  </svg>
);

export const Sparkle = ({ size = 14 }: P) => (
  <svg {...base(size)}>
    <path d="M12 3l1.6 5.4L19 10l-5.4 1.6L12 17l-1.6-5.4L5 10l5.4-1.6L12 3z" fill="currentColor" stroke="none" />
  </svg>
);

export const Gear = ({ size = 16 }: P) => (
  <svg {...base(size)}>
    <circle cx="12" cy="12" r="3" />
    <path d="M12 2v2m0 16v2M4.9 4.9l1.4 1.4m11.4 11.4l1.4 1.4M2 12h2m16 0h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4" />
  </svg>
);

export const ChevronLeft = ({ size = 15 }: P) => (
  <svg {...base(size)}><path d="M15 6l-6 6 6 6" /></svg>
);
export const ChevronRight = ({ size = 15 }: P) => (
  <svg {...base(size)}><path d="M9 6l6 6-6 6" /></svg>
);
export const ArrowDown = ({ size = 14 }: P) => (
  <svg {...base(size)}><path d="M12 5v14M6 13l6 6 6-6" /></svg>
);
export const ArrowUp = ({ size = 14 }: P) => (
  <svg {...base(size)}><path d="M12 19V5M6 11l6-6 6 6" /></svg>
);
export const Check = ({ size = 13 }: P) => (
  <svg {...base(size)}><path d="M20 6L9 17l-5-5" /></svg>
);
export const Warning = ({ size = 15 }: P) => (
  <svg {...base(size)}><path d="M12 9v4m0 4h.01M10.3 3.9L1.8 18a2 2 0 001.7 3h17a2 2 0 001.7-3L14.7 3.9a2 2 0 00-3.4 0z" /></svg>
);
export const Radar = ({ size = 15 }: P) => (
  <svg {...base(size)}><path d="M19.1 4.9A10 10 0 1 0 22 12" /><path d="M12 12l6-3" /><circle cx="12" cy="12" r="1.4" fill="currentColor" stroke="none" /><path d="M15.5 8.5A5 5 0 1 0 17 12" /></svg>
);
export const Question = ({ size = 14 }: P) => (
  <svg {...base(size)}><circle cx="12" cy="12" r="9" /><path d="M9.5 9.5a2.5 2.5 0 1 1 3.6 2.2c-.8.4-1.1 1-1.1 1.8m0 3h.01" /></svg>
);
export const Wallet = ({ size = 16 }: P) => (
  <svg {...base(size)}><rect x="3" y="6" width="18" height="13" rx="2.5" /><path d="M3 9h18M17 13h.5" /></svg>
);
export const Close = ({ size = 15 }: P) => (
  <svg {...base(size)}><path d="M6 6l12 12M18 6L6 18" /></svg>
);

/* Category glyphs */
export const Cart = ({ size = 15 }: P) => (
  <svg {...base(size)}><path d="M3 4h2l2.2 11.4a1 1 0 001 .8h8.8a1 1 0 001-.8L20 8H6" /><circle cx="9" cy="20" r="1.2" fill="currentColor" stroke="none" /><circle cx="17" cy="20" r="1.2" fill="currentColor" stroke="none" /></svg>
);
export const Home = ({ size = 15 }: P) => (
  <svg {...base(size)}><path d="M4 11l8-6 8 6M6 10v9h12v-9" /></svg>
);
export const Car = ({ size = 15 }: P) => (
  <svg {...base(size)}><path d="M4 13l1.5-4.5A2 2 0 017.4 7h9.2a2 2 0 011.9 1.5L20 13v4h-2m-12 0H4v-4m0 0h16" /><circle cx="7.5" cy="17" r="1.3" fill="currentColor" stroke="none" /><circle cx="16.5" cy="17" r="1.3" fill="currentColor" stroke="none" /></svg>
);
export const Play = ({ size = 15 }: P) => (
  <svg {...base(size)}><rect x="3" y="5" width="18" height="14" rx="3" /><path d="M10 9.5l5 2.5-5 2.5v-5z" fill="currentColor" stroke="none" /></svg>
);
export const Shield = ({ size = 15 }: P) => (
  <svg {...base(size)}><path d="M12 3l7 3v5c0 4.5-3 8-7 10-4-2-7-5.5-7-10V6l7-3z" /></svg>
);
export const Bolt = ({ size = 15 }: P) => (
  <svg {...base(size)}><path d="M13 3L5 13h6l-1 8 8-10h-6l1-8z" fill="currentColor" stroke="none" /></svg>
);
export const Heart = ({ size = 15 }: P) => (
  <svg {...base(size)}><path d="M12 20s-7-4.3-7-9.3A3.7 3.7 0 0 1 12 8a3.7 3.7 0 0 1 7 2.7c0 5-7 9.3-7 9.3z" /></svg>
);
export const Bag = ({ size = 15 }: P) => (
  <svg {...base(size)}><path d="M6 8h12l-1 12H7L6 8z" /><path d="M9 8a3 3 0 0 1 6 0" /></svg>
);
export const Cash = ({ size = 15 }: P) => (
  <svg {...base(size)}><rect x="2" y="6" width="20" height="12" rx="2" /><circle cx="12" cy="12" r="2.4" /></svg>
);
export const Coins = ({ size = 15 }: P) => (
  <svg {...base(size)}><ellipse cx="12" cy="7" rx="7" ry="3" /><path d="M5 7v5c0 1.7 3.1 3 7 3s7-1.3 7-3V7M5 12v5c0 1.7 3.1 3 7 3s7-1.3 7-3v-5" /></svg>
);
export const Dot = ({ size = 15 }: P) => (
  <svg {...base(size)}><circle cx="12" cy="12" r="3.4" fill="currentColor" stroke="none" /></svg>
);

export function CategoryIcon({ category, size = 15 }: { category: Category; size?: number }) {
  switch (category) {
    case "income": return <Coins size={size} />;
    case "housing": return <Home size={size} />;
    case "transport": return <Car size={size} />;
    case "groceries": return <Cart size={size} />;
    case "eating-out": return <Bag size={size} />;
    case "subscriptions": return <Play size={size} />;
    case "insurance": return <Shield size={size} />;
    case "utilities": return <Bolt size={size} />;
    case "health": return <Heart size={size} />;
    case "debt": return <Home size={size} />;
    case "savings": return <Coins size={size} />;
    case "shopping": return <Bag size={size} />;
    case "cash": return <Cash size={size} />;
    default: return <Dot size={size} />;
  }
}
