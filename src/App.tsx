import { useCallback, useEffect, useRef, useState } from "react";
import { AnimatePresence, motion } from "framer-motion";
import { useHorizon } from "./hooks/useHorizon";
import { useSettings } from "./hooks/useSettings";
import { MenuBar } from "./components/MenuBar";
import { QuickView } from "./components/QuickView";
import { FutureView } from "./components/FutureView";
import { WhatsNext } from "./components/WhatsNext";
import { EventDetail } from "./components/EventDetail";
import { Settings } from "./components/Settings";
import { CommandBar } from "./components/CommandBar";
import { Onboarding } from "./components/Onboarding";
import type { UpcomingEvent } from "./types";

type Screen = "quick" | "future" | "whatsnext" | "detail" | "settings";

export default function App() {
  const state = useHorizon();
  const { settings, toggle: toggleSetting } = useSettings();
  const [open, setOpen] = useState(true);
  const [screen, setScreen] = useState<Screen>("quick");
  const [selected, setSelected] = useState<UpcomingEvent | null>(null);
  const [cmdOpen, setCmdOpen] = useState(false);
  const popRef = useRef<HTMLDivElement>(null);

  const toggle = useCallback(() => setOpen((o) => !o), []);

  // Keyboard shortcuts: ⌘⇧B toggle, ⌘K command bar, Esc close.
  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if ((e.metaKey || e.ctrlKey) && e.shiftKey && e.key.toLowerCase() === "b") {
        e.preventDefault();
        toggle();
      } else if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "k") {
        e.preventDefault();
        if (open) setCmdOpen((c) => !c);
      } else if (e.key === "Escape") {
        if (cmdOpen) setCmdOpen(false);
        else if (screen !== "quick") back();
        else setOpen(false);
      }
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [open, cmdOpen, screen, toggle]);

  // Click outside closes the popover (like a real menu-bar app).
  useEffect(() => {
    function onDown(e: MouseEvent) {
      if (!open || cmdOpen) return;
      if (popRef.current && !popRef.current.contains(e.target as Node)) {
        const pill = (e.target as HTMLElement).closest(".menu-pill");
        if (!pill) setOpen(false);
      }
    }
    window.addEventListener("mousedown", onDown);
    return () => window.removeEventListener("mousedown", onDown);
  }, [open, cmdOpen]);

  function back() {
    setScreen("quick");
    setSelected(null);
  }

  function openEvent(e: UpcomingEvent) {
    setSelected(e);
    setScreen("detail");
  }

  return (
    <div className="desktop">
      <MenuBar forecast={state.base} open={open && state.onboarded} onToggle={toggle} />

      <AnimatePresence>
        {!state.onboarded && (
          <Onboarding
            onConnect={state.connect}
            onDone={() => {
              setScreen("quick");
              setOpen(true);
            }}
          />
        )}
      </AnimatePresence>

      <AnimatePresence>
        {open && state.base && state.snapshot && (
          <div className="popover-anchor">
            <motion.div
              ref={popRef}
              className="popover"
              initial={{ opacity: 0, scale: 0.94, y: -8 }}
              animate={{ opacity: 1, scale: 1, y: 0 }}
              exit={{ opacity: 0, scale: 0.96, y: -8 }}
              transition={{ duration: 0.22, ease: [0.22, 0.9, 0.28, 1] }}
            >
              <div className="popover-arrow" />

              <AnimatePresence mode="wait">
                <motion.div
                  key={screen}
                  className="pop-screen"
                  initial={{ opacity: 0, x: screen === "quick" ? -14 : 14 }}
                  animate={{ opacity: 1, x: 0 }}
                  exit={{ opacity: 0, x: screen === "quick" ? 14 : -14 }}
                  transition={{ duration: 0.26, ease: [0.22, 0.8, 0.28, 1] }}
                >
                  {screen === "quick" && (
                    <QuickView
                      forecast={state.base}
                      transactions={state.transactions}
                      today={state.today}
                      source={state.snapshot.source}
                      onOpenFuture={() => setScreen("future")}
                      onOpenWhatsNext={() => setScreen("whatsnext")}
                      onOpenSettings={() => setScreen("settings")}
                      onSelectEvent={openEvent}
                    />
                  )}
                  {screen === "future" && (
                    <FutureView
                      base={state.base}
                      today={state.today}
                      forecastWith={state.forecastWith}
                      onBack={back}
                      onSelectEvent={openEvent}
                    />
                  )}
                  {screen === "whatsnext" && (
                    <WhatsNext
                      forecast={state.base}
                      today={state.today}
                      onBack={back}
                      onSelectEvent={openEvent}
                    />
                  )}
                  {screen === "detail" && selected && (
                    <EventDetail
                      event={selected}
                      note={state.notes[selected.id] ?? ""}
                      onNote={(v) => state.setNote(selected.id, v)}
                      onBack={() => setScreen("quick")}
                    />
                  )}
                  {screen === "settings" && (
                    <Settings
                      snapshot={state.snapshot}
                      settings={settings}
                      toggle={toggleSetting}
                      refreshMinutes={state.refreshMinutes}
                      setRefreshMinutes={state.setRefreshMinutes}
                      lastUpdated={state.lastUpdated}
                      refreshing={state.refreshing}
                      onRefreshNow={() => void state.refreshNow()}
                      onBack={back}
                      onDisconnect={() => {
                        setScreen("quick");
                        state.disconnect();
                      }}
                      onQuit={() => {
                        setScreen("quick");
                        setOpen(false);
                      }}
                    />
                  )}
                </motion.div>
              </AnimatePresence>
            </motion.div>
          </div>
        )}
      </AnimatePresence>

      <AnimatePresence>
        {cmdOpen && state.base && (
          <CommandBar
            base={state.base}
            today={state.today}
            forecastWith={state.forecastWith}
            onClose={() => setCmdOpen(false)}
          />
        )}
      </AnimatePresence>

      {!open && (
        <div className="hint">
          Click the balance in the menu bar, or press <span className="kbd">⌘⇧B</span>
        </div>
      )}
      {open && !cmdOpen && (
        <div className="hint">
          <span className="kbd">⌘K</span> ask your money
          <span style={{ opacity: 0.5 }}>·</span>
          <span className="kbd">esc</span> close
        </div>
      )}
    </div>
  );
}
