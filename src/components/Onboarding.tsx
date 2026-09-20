import { useEffect, useState } from "react";
import { AnimatePresence, motion } from "framer-motion";
import type { SourceChoice } from "../hooks/useHorizon";
import type { InvestecCredentials } from "../services/adapters/investecAdapter";
import { Sparkle, Check, Wallet, Coins, Radar, Shield, ChevronLeft, ChevronRight, HorizonMark } from "./icons";

interface Props {
  onConnect: (source: SourceChoice, creds?: InvestecCredentials) => Promise<void>;
  onDone: () => void;
}

type Step = "welcome" | "connect" | "keys" | "analyzing";

const ANALYSIS_STEPS = [
  { icon: <Wallet size={15} />, label: "Reading account & balance" },
  { icon: <Radar size={15} />, label: "Detecting recurring payments" },
  { icon: <Coins size={15} />, label: "Estimating typical spending" },
  { icon: <Sparkle size={13} />, label: "Building your forecast" },
];

export function Onboarding({ onConnect, onDone }: Props) {
  const [step, setStep] = useState<Step>("welcome");
  const [error, setError] = useState<string | null>(null);

  async function run(creds?: InvestecCredentials, fallback: Step = "connect") {
    setError(null);
    setStep("analyzing");
    try {
      await Promise.all([onConnect("live", creds), delay(2000)]);
      onDone();
    } catch (e) {
      setError((e as Error).message);
      setStep(fallback);
    }
  }

  return (
    <div className="onboard-scrim">
      <div className="orb orb-a" />
      <div className="orb orb-b" />
      <div className="orb orb-c" />

      <AnimatePresence mode="wait">
        <motion.div
          key={step}
          className="onboard-card"
          initial={{ opacity: 0, y: 16, filter: "blur(6px)" }}
          animate={{ opacity: 1, y: 0, filter: "blur(0px)" }}
          exit={{ opacity: 0, y: -12, filter: "blur(6px)" }}
          transition={{ duration: 0.42, ease: [0.22, 0.8, 0.28, 1] }}
        >
          {step === "welcome" && <Welcome onNext={() => setStep("connect")} />}
          {step === "connect" && (
            <Connect
              error={error}
              onSandbox={() => run()}
              onOwn={() => { setError(null); setStep("keys"); }}
            />
          )}
          {step === "keys" && (
            <KeyForm
              error={error}
              onBack={() => { setError(null); setStep("connect"); }}
              onSubmit={(creds) => run(creds, "keys")}
            />
          )}
          {step === "analyzing" && <Analyzing />}
        </motion.div>
      </AnimatePresence>

      <div className="onboard-foot">
        Horizon · shows estimates, never moves money · not financial advice
      </div>
    </div>
  );
}

function Welcome({ onNext }: { onNext: () => void }) {
  return (
    <>
      <div className="ob-badge">
        <span className="logo-mark"><HorizonMark size={20} /></span>
      </div>
      <div className="ob-kicker">HORIZON</div>
      <h1 className="ob-title">
        Your balance,<br />and what it&apos;s<br />about to do next.
      </h1>
      <p className="ob-sub">
        A tiny glass utility that lives in your menu bar. One glance shows what you have now,
        where it&apos;s heading, and exactly why.
      </p>

      <div className="ob-hero-line">
        <svg viewBox="0 0 320 60" preserveAspectRatio="none" style={{ width: "100%", height: 60 }}>
          <defs>
            <linearGradient id="obGrad" x1="0" y1="0" x2="1" y2="0">
              <stop offset="0%" stopColor="#c88a4a" />
              <stop offset="100%" stopColor="#9fb0c2" />
            </linearGradient>
          </defs>
          <motion.path
            d="M4 40 C 60 40, 70 12, 110 12 S 180 44, 230 40 S 300 52, 316 50"
            fill="none"
            stroke="url(#obGrad)"
            strokeWidth={2.4}
            strokeLinecap="round"
            initial={{ pathLength: 0 }}
            animate={{ pathLength: 1 }}
            transition={{ duration: 1.4, ease: "easeInOut" }}
          />
          <motion.circle
            cx={110} cy={12} r={4} fill="#f4f4f2"
            initial={{ scale: 0 }} animate={{ scale: 1 }} transition={{ delay: 0.9 }}
          />
        </svg>
      </div>

      <button className="btn" onClick={onNext}>
        Get started <ChevronRight size={14} />
      </button>
    </>
  );
}

function Connect({ error, onSandbox, onOwn }: { error: string | null; onSandbox: () => void; onOwn: () => void }) {
  return (
    <>
      <div className="ob-kicker">CONNECT YOUR ACCOUNT</div>
      <h2 className="ob-title sm">Connect to Investec</h2>
      <p className="ob-sub">
        Horizon reads your accounts through the Investec API, <strong>read-only</strong>. It
        never moves money, and keys are never stored in the app.
      </p>

      <button className="ob-choice" onClick={onOwn}>
        <span className="oc-glyph live"><Wallet size={18} /></span>
        <span className="oc-body">
          <span className="oc-title">Your Investec account <span className="oc-tag">API KEY</span></span>
          <span className="oc-desc">Attach your own programmable-banking API key.</span>
        </span>
        <ChevronRight size={16} />
      </button>

      <button className="ob-choice" onClick={onSandbox}>
        <span className="oc-glyph"><Shield size={18} /></span>
        <span className="oc-body">
          <span className="oc-title">Investec sandbox</span>
          <span className="oc-desc">Try it with the shared test account (Mr Smith).</span>
        </span>
        <ChevronRight size={16} />
      </button>

      {error && <div className="ob-error"><Shield size={13} /> {error}</div>}

      <div className="ob-privacy">
        <Check size={12} /> Read-only access
        <span className="sep">·</span>
        <Check size={12} /> No money movement
        <span className="sep">·</span>
        <Check size={12} /> Disconnect anytime
      </div>
    </>
  );
}

function KeyForm({
  error,
  onBack,
  onSubmit,
}: {
  error: string | null;
  onBack: () => void;
  onSubmit: (creds: InvestecCredentials) => void;
}) {
  const [clientId, setClientId] = useState("");
  const [secret, setSecret] = useState("");
  const [apiKey, setApiKey] = useState("");
  const [environment, setEnvironment] = useState<"production" | "sandbox">("production");
  const ready = clientId.trim() && secret.trim() && apiKey.trim();

  return (
    <>
      <button className="ob-back" onClick={onBack}>
        <ChevronLeft size={14} /> Back
      </button>
      <div className="ob-kicker">ATTACH YOUR API KEY</div>
      <h2 className="ob-title sm">Your Investec keys</h2>
      <p className="ob-sub" style={{ marginBottom: 14 }}>
        From Investec Online → Manage → Investec Developer → Individual Connections → Create new
        API key.
      </p>

      <div className="ob-field">
        <label>Client ID</label>
        <input value={clientId} onChange={(e) => setClientId(e.target.value)} placeholder="Your client ID" autoComplete="off" spellCheck={false} />
      </div>
      <div className="ob-field">
        <label>Client secret</label>
        <input type="password" value={secret} onChange={(e) => setSecret(e.target.value)} placeholder="Your client secret" autoComplete="off" spellCheck={false} />
      </div>
      <div className="ob-field">
        <label>API key</label>
        <input type="password" value={apiKey} onChange={(e) => setApiKey(e.target.value)} placeholder="x-api-key value" autoComplete="off" spellCheck={false} />
      </div>

      <div className="ob-seg">
        <button className={environment === "production" ? "on" : ""} onClick={() => setEnvironment("production")}>Production</button>
        <button className={environment === "sandbox" ? "on" : ""} onClick={() => setEnvironment("sandbox")}>Sandbox</button>
      </div>

      {error && <div className="ob-error"><Shield size={13} /> {error}</div>}

      <div className="ob-hint">
        <Shield size={13} />
        <span>Keys go only to Horizon&apos;s own backend to call Investec. They are never put in the browser bundle, saved to disk, or committed.</span>
      </div>

      <button
        className="btn"
        style={{ marginTop: 14, opacity: ready ? 1 : 0.5, pointerEvents: ready ? "auto" : "none" }}
        onClick={() => ready && onSubmit({ clientId: clientId.trim(), secret: secret.trim(), apiKey: apiKey.trim(), environment })}
      >
        Connect securely <ChevronRight size={14} />
      </button>
    </>
  );
}

function Analyzing() {
  const [done, setDone] = useState(0);
  useEffect(() => {
    const timers = ANALYSIS_STEPS.map((_, i) =>
      setTimeout(() => setDone((d) => Math.max(d, i + 1)), 350 + i * 420),
    );
    return () => timers.forEach(clearTimeout);
  }, []);

  return (
    <>
      <div className="ob-kicker">ANALYSING</div>
      <h2 className="ob-title sm">Building your forecast</h2>
      <p className="ob-sub">Reading recent activity to project where your balance is heading.</p>

      <div className="ob-analysis">
        {ANALYSIS_STEPS.map((s, i) => {
          const state = i < done ? "done" : i === done ? "active" : "idle";
          return (
            <motion.div
              key={s.label}
              className={`oa-row ${state}`}
              initial={{ opacity: 0, x: -8 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ delay: i * 0.12 }}
            >
              <span className="oa-icon">
                {state === "done" ? <Check size={14} /> : s.icon}
              </span>
              <span className="oa-label">{s.label}</span>
              {state === "active" && <span className="oa-spin" />}
            </motion.div>
          );
        })}
      </div>
    </>
  );
}

function delay(ms: number) {
  return new Promise((r) => setTimeout(r, ms));
}
