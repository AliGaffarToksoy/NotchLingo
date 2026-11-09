# Delivery roadmap

1. **Delivered:** Swift package, SwiftData models and store, 30 cards per track,
   versioned JSON contract, SM-2-based scheduler, daily budget/streak helpers, unit tests,
   and a minimal foundation window.
2. **Next, on request:** custom notch panel, collapsed/expanded state, display fallback,
   menu bar commands, configurable global hotkey, and flashcard module end to end.
3. Quiz modules (cloze, multiple choice, meaning/naturalness selection, sentence builder),
   passive pop-quiz scheduler, active hours, snooze, and best-effort Focus handling.
4. Speaking/listening, local TTS, on-device-only speech recognition where supported,
   similarity feedback (not a clinical or phonetic pronunciation score), permissions onboarding.
5. Dashboard and charts, settings, deck browser, JSON/CSV import/export UI,
   150+ cards per track, weighted session orchestration across enabled modules.
6. Optional disabled-by-default AI provider interface and Keychain integration,
   accessibility/Reduce Motion polish, app bundle/signing, release packaging instructions.

Each phase stops for review. No server, account, telemetry, or network dependency is needed
for the core app. Opt-in remote AI would send only explicitly submitted content to a selected provider.
