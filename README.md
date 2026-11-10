# NotchLingo

**Türkçe ve İngilizce arayüzlü, çevrimdışı macOS İngilizce öğrenme uygulaması.**
English micro-learning in your MacBook notch, with Turkish meanings and an optional English interface.

[Download the latest app / Uygulamayı indir](https://github.com/AliGaffarToksoy/NotchLingo/releases/latest)

## Install — no Xcode required

1. Download `NotchLingo-macOS-arm64.dmg` from Releases (Apple Silicon, macOS 14+).
2. Open the DMG and drag **NotchLingo** onto **Applications**.
3. Open NotchLingo from Applications. The welcome guide appears; the menu bar and top pill stay available when the dashboard closes.
4. This personal build is ad-hoc signed, **not Apple-notarized**. If macOS blocks it, open **System Settings → Privacy & Security → Open Anyway** after trying to launch it. Approve only the build you downloaded from this repository. No system-wide security changes are needed.

ZIP is also available: extract it and drag `NotchLingo.app` to Applications. Check `SHA256SUMS.txt` if you want to verify the downloaded archive. Intel Macs are not included in this release.

### Türkçe kurulum

Releases sayfasından `.dmg` dosyasını indir, aç ve **NotchLingo** simgesini **Applications / Uygulamalar** klasörüne sürükle. Uygulamayı Uygulamalar'dan aç. Xcode, VS Code, terminal veya Python gerekmez. macOS ilk açılışı engellerse **Sistem Ayarları → Gizlilik ve Güvenlik → Yine de Aç** seçeneğini kullan. Bu sürüm Apple noter onayına sahip değildir.

## What is included

- Custom top-center notch panel: collapses to the word of the day, expands for exercises, and falls back to a floating pill without a notch. It prefers the notched built-in screen when available.
- Turkish and English interface, bilingual definitions on every card, US/UK TTS selector, IPA, examples, notes, tags.
- **300 original seed cards:** 150 Everyday English and 150 Tech / Work English (Cloud, DevOps, software, meetings, interviews).
- Flashcards; meaning choices; cloze; natural-sentence selection; sentence builder; listening dictation; on-device speaking practice.
- Four ratings: Again / Hard / Good / Easy. SM-2-inspired scheduling, 1-minute and 10-minute learning steps, daily new/review caps, track weights, leech practice.
- 1/3/5-minute sessions; due short steps first, then due reviews, then new cards. Sessions stop after the chosen time; unfinished cards are not rated automatically.
- Menu bar commands, configurable ⌥⌘L / ⌥⌘Space / ⌥⌘N global shortcut, pause for one hour, active hours, optional launch at login.
- Optional 20-second passive notch quizzes with snooze and dismissal. Passive panels never request keyboard focus. User-opened sessions can accept typing.
- Dashboard: daily goals, streak, recall, time spent, state counts, 30-day chart, weak words, searchable/tag-filtered deck browser.
- JSON and RFC 4180 CSV import/export. Imports validate before saving and preserve existing progress. No cards are silently deleted.
- Optional **OpenAI / Anthropic / local Ollama** workshop: feedback, new examples, and generated cards reviewed before import. Disabled by default; keys stored in macOS Keychain.
- Keyboard navigation, VoiceOver labels, and Reduce Motion-aware panel resizing.

## Privacy and platform limits

Core learning has no account, telemetry, backend, or network requirement. SwiftData stores progress in
`~/Library/Application Support/NotchLingo/NotchLingo.store`. Preferences use UserDefaults. CloudKit is disabled.
Deleting the app does not delete learning progress. Do not delete the store to fix an ordinary startup error.

Microphone/speech access is requested only when you begin speaking. Recognition explicitly requires on-device processing; unavailable device/language support produces an explanation, with no server fallback. Audio is not saved. Transcript comparison finds missing/different words; it is **not a phonetic pronunciation diagnosis**. Offline voice availability depends on voices installed in macOS; add voices in Accessibility settings if needed.

Reminders are off initially. Standard notifications follow macOS Focus settings. Direct notch quizzes are a separate opt-in setting: macOS has no universal public Focus query, so **direct notch quizzes cannot guarantee Focus suppression**. Keep direct quizzes off for Focus-aware reminders. Sleeping the Mac stops the active session and resets reminder timing on wake.

The AI workshop sends only the text explicitly submitted there to the selected provider. Cloud providers may charge the configured API account and apply their own data policies. OpenAI requests use `store: false`; this does not promise zero provider retention. Ollama URLs are restricted to loopback addresses. No API key is bundled. Provider model names are editable because account availability varies.

The natural-sentence exercise uses original sentences and scrambled distractors. CEFR/IPA are editorial guidance, not official certification; language-teacher review is welcome. Notch behavior on different hardware and multiple monitors needs broader real-device testing.

## Developer build

Developers need full Xcode 15+ selected in Xcode → Settings → Locations → Command Line Tools.
End users only need the downloaded application.

```sh
git clone https://github.com/AliGaffarToksoy/NotchLingo.git
cd NotchLingo
swift test
swift run NotchLingoValidate
bash Scripts/package.sh
open dist/NotchLingo.app
```

Open `Package.swift` in Xcode to edit. Use the NotchLingo executable scheme / My Mac.
The unsandboxed development app uses public macOS APIs and requests only the needed permissions.
`Scripts/package.sh` builds arm64, copies resource bundles, creates the icon/Info.plist, ad-hoc signs,
verifies the signature, and produces ZIP and DMG archives. No signing certificate or Apple Developer
subscription is required for this personal distribution.

For core smoke checks on machines without full Xcode:

```sh
NOTCHLINGO_CORE_ONLY=1 swift run NotchLingoValidate
```

This does not replace full tests or build the GUI. `NOTCHLINGO_CORE_ONLY=1 swift test` also works if XCTest is available.

GitHub Actions runs unit and SwiftData persistence tests, validates all bundled cards, builds and packages
on a hosted macOS runner, and publishes versioned releases only after success. Pull requests test/package
without publishing. A failed build never produces a release.

## Architecture

```text
Decks/                         # Canonical bundled JSON, 150 cards per track
Schema/deck.schema.json
Sources/NotchLingoCore/         # Pure SRS, planner, exercises, JSON/CSV codecs
Sources/NotchLingoStorage/      # SwiftData models, atomic saves/imports
Sources/NotchLingoApp/          # Observable view model, SwiftUI screens, AppKit panel
  Services/                    # Speech/TTS, hotkey, notifications, AI/Keychain
  Views/                       # Dashboard, decks, exercises, settings, AI workshop
Sources/NotchLingoValidate/     # Content and domain smoke validator
Tests/                         # Domain, parser, import, persistence tests
Scripts/                       # App packaging and icon generation
.github/workflows/build.yml    # Hosted macOS tests, build, release
```

`LearningModule` is the UI-independent exercise extension point. `AIProvider` is the opt-in generation
interface. Content and progress are separate, so importing a newer deck does not reset review intervals.
Read [deck format](docs/DECK_FORMAT.md), [scheduling policy](docs/SCHEDULING.md), and [CONTRIBUTING.md](CONTRIBUTING.md).

A custom `NSPanel` gives direct control over focus, screen selection, and fallback behavior;
[DynamicNotchKit](https://github.com/mrkai77/DynamicNotchKit) was considered as an alternative.
We keep the app dependency-free and own the passive/interactive transition explicitly.

API references: [Apple on-device speech](https://developer.apple.com/documentation/speech/sfspeechrecognizer/supportsondevicerecognition),
[OpenAI Responses](https://developers.openai.com/api/docs/guides/migrate-to-responses),
[Anthropic Messages](https://platform.claude.com/docs/en/api/messages/create),
[Ollama API](https://github.com/ollama/ollama/blob/main/docs/api.md).

## Screenshots

Screenshots from the packaged app are added under `docs/` after local launch verification.

MIT licensed. See [LICENSE](LICENSE).
