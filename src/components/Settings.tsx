import type { BankSnapshot } from "../services/bankingService";
import type { AppSettings } from "../hooks/useSettings";
import { REFRESH_STEPS } from "../hooks/useHorizon";
import {
  ChevronLeft,
  ChevronRight,
  Warning,
  Wallet,
  Sparkle,
  Bolt,
  Radar,
  Coins,
  Gear,
  Close,
  Check,
} from "./icons";

interface Props {
  snapshot: BankSnapshot;
  settings: AppSettings;
  toggle: (key: keyof AppSettings) => void;
  refreshMinutes: number;
  setRefreshMinutes: (m: number) => void;
  lastUpdated: number | null;
  refreshing: boolean;
  onRefreshNow: () => void;
  onBack: () => void;
  onDisconnect: () => void;
  onQuit: () => void;
}

function Switch({ on, onToggle }: { on: boolean; onToggle: () => void }) {
  return (
    <button className={`switch ${on ? "on" : ""}`} onClick={onToggle} aria-pressed={on}>
      <i />
    </button>
  );
}

function Row({
  glyph,
  title,
  sub,
  right,
  onClick,
  onWheel,
}: {
  glyph: React.ReactNode;
  title: string;
  sub: string;
  right: React.ReactNode;
  onClick?: () => void;
  onWheel?: (e: React.WheelEvent) => void;
}) {
  return (
    <div className={`menu-row ${onClick ? "tappable" : ""}`} onClick={onClick} onWheel={onWheel}>
      <span className="mr-glyph">{glyph}</span>
      <span className="mr-body">
        <div className="mr-title">{title}</div>
        <div className="mr-sub">{sub}</div>
      </span>
      {right}
    </div>
  );
}

function ago(ts: number | null): string {
  if (!ts) return "not yet";
  const s = Math.round((Date.now() - ts) / 1000);
  if (s < 60) return "just now";
  const m = Math.round(s / 60);
  if (m < 60) return `${m} min ago`;
  return `${Math.round(m / 60)} h ago`;
}

export function Settings({
  snapshot,
  settings,
  toggle,
  refreshMinutes,
  setRefreshMinutes,
  lastUpdated,
  refreshing,
  onRefreshNow,
  onBack,
  onDisconnect,
  onQuit,
}: Props) {
  const idx = REFRESH_STEPS.indexOf(refreshMinutes as (typeof REFRESH_STEPS)[number]);
  const step = (dir: number) => {
    const next = Math.max(0, Math.min(REFRESH_STEPS.length - 1, idx + dir));
    setRefreshMinutes(REFRESH_STEPS[next]);
  };

  return (
    <div className="popover-inner">
      <div className="pop-head">
        <button className="back-btn" onClick={onBack}>
          <ChevronLeft size={15} /> Balance
        </button>
        <div className="brand" style={{ marginLeft: "auto", fontSize: 12, color: "var(--ink-dim)" }}>
          Settings
        </div>
      </div>

      <span className="label">Connection</span>
      <div className="menu-list" style={{ marginTop: 6 }}>
        <Row
          glyph={<Wallet size={16} />}
          title="Data source"
          sub={`${snapshot.source} · ${snapshot.transactions.length} transactions`}
          right={<button className="mr-btn primary" onClick={onDisconnect}>Switch</button>}
        />
        <Row
          glyph={<Coins size={16} />}
          title={snapshot.account.name}
          sub={`Account ${snapshot.account.number || "sandbox"}`}
          right={<ChevronRight size={15} />}
        />
        {/* Auto-refresh interval: click +/- or scroll over the row to change. */}
        <Row
          glyph={<Radar size={15} />}
          title="Auto-refresh"
          sub={`Every ${refreshMinutes} min · updated ${ago(lastUpdated)}`}
          onWheel={(e) => step(e.deltaY < 0 ? 1 : -1)}
          right={
            <div className="stepper">
              <button onClick={() => step(-1)} disabled={idx <= 0} aria-label="Less often">−</button>
              <span className="stepper-val num">{refreshMinutes}m</span>
              <button onClick={() => step(1)} disabled={idx >= REFRESH_STEPS.length - 1} aria-label="More often">+</button>
            </div>
          }
        />
        <Row
          glyph={<Sparkle size={13} />}
          title="Refresh now"
          sub={refreshing ? "Fetching latest…" : "Pull the latest balance and transactions"}
          onClick={onRefreshNow}
          right={<button className="mr-btn" onClick={onRefreshNow}>{refreshing ? "…" : "Refresh"}</button>}
        />
      </div>

      <span className="label" style={{ display: "block", marginTop: 16 }}>General</span>
      <div className="menu-list" style={{ marginTop: 6 }}>
        <Row
          glyph={<Bolt size={15} />}
          title="Launch at login"
          sub="Open Horizon when your Mac starts"
          right={<Switch on={settings.launchAtLogin} onToggle={() => toggle("launchAtLogin")} />}
        />
        <Row
          glyph={<Radar size={15} />}
          title="Run in background"
          sub="Keep the menu-bar item running when closed"
          right={<Switch on={settings.runInBackground} onToggle={() => toggle("runInBackground")} />}
        />
        <Row
          glyph={<Sparkle size={13} />}
          title="Hide menu bar icons"
          sub={settings.hideMenuIcons ? "On" : "Off"}
          right={<Switch on={settings.hideMenuIcons} onToggle={() => toggle("hideMenuIcons")} />}
        />
        <Row
          glyph={<Bolt size={15} />}
          title="Dark mode"
          sub={settings.darkMode ? "On" : "Off"}
          right={<Switch on={settings.darkMode} onToggle={() => toggle("darkMode")} />}
        />
        <Row
          glyph={<Warning size={14} />}
          title="Balance alerts"
          sub="Warn before a low buffer"
          right={<Switch on={settings.balanceAlerts} onToggle={() => toggle("balanceAlerts")} />}
        />
        <Row
          glyph={<Bolt size={15} />}
          title="Keep awake"
          sub="Prevent idle sleep while open"
          right={<Switch on={settings.keepAwake} onToggle={() => toggle("keepAwake")} />}
        />
      </div>

      {snapshot.usedFallback && (
        <div className="callout" style={{ marginTop: 12 }}>
          <span className="co-icon"><Warning size={14} /></span>
          <span>Live sandbox was unreachable, showing synthetic data instead.</span>
        </div>
      )}

      <div className="assumptions" style={{ marginTop: 14 }}>
        <span className="label" style={{ display: "block", marginBottom: 6 }}>Privacy</span>
        <div className="assump-item"><span className="check"><Check size={12} /></span>Read-only account access</div>
        <div className="assump-item"><span className="check"><Check size={12} /></span>Keys held on the backend, never in the app</div>
        <div style={{ fontSize: 11, color: "var(--ink-ghost)", marginTop: 6, lineHeight: 1.5 }}>
          Horizon never moves money. Forecasts are estimates based on recent activity, not
          guaranteed outcomes or financial advice.
        </div>
      </div>

      <div className="menu-sep" />

      <div className="menu-foot danger" onClick={onDisconnect}>
        <Close size={15} /> Disconnect and remove data
      </div>
      <div className="menu-foot" onClick={onQuit}>
        <Gear size={15} /> Close Horizon
      </div>
    </div>
  );
}
