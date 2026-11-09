# NotchLingo

Offline English micro-learning for a Turkish-speaking engineer, built for macOS 14+.
Swift 5.9+, SwiftUI, SwiftData. MIT licensed; no third-party packages or backend.

**Phase 1 is implemented.** This is a compilable foundation, not the completed notch app.
The executable opens a small window confirming that both seed decks have loaded locally.
Notch UI, exercises, audio, notifications, import/export UI, and the full dashboard follow
in the phases listed in [ROADMAP.md](ROADMAP.md).

## Run

On an Apple Silicon Mac with macOS 14+ and the full Xcode 15+ installation selected as the developer directory:

```sh
cd /Users/alitoksoy/PycharmProjects/NotchLingo
swift test
swift run NotchLingo
```

After cloning elsewhere, change the `cd` path to your checkout. In Xcode, choose **File → Open**,
select `Package.swift`, select the **NotchLingo** executable scheme and **My Mac**, then
**Product → Run** (⌘R). Run tests with **Product → Test** (⌘U); select the NotchLingo-Package
scheme if the executable scheme has no tests enabled. No signing team or API key is needed
for the development executable. This phase is a Swift package executable; a distributable
`.app`, permissions metadata, signing, and release packaging will be added in later phases.

The local store is `~/Library/Application Support/NotchLingo/NotchLingo.store`
(with SQLite companion files). CloudKit is explicitly disabled. Seed loading is idempotent,
and startup errors are displayed without deleting the existing store. Tests use isolated
in-memory stores or temporary directories, never your app's data.

If `xcode-select -p` points to `/Library/Developer/CommandLineTools`, install full Xcode
and select it in **Xcode → Settings → Locations → Command Line Tools**. Command-line tools
alone can lack the SwiftData macro plug-in needed for `@Model`.

For **core-only smoke validation** without full Xcode:

```sh
NOTCHLINGO_CORE_ONLY=1 swift run NotchLingoValidate
```

This checks bundled content, JSON round trips and rejection, learning steps, lapse handling,
leech detection, track balance, and budget bypass. If your toolchain also has XCTest, you can
run `NOTCHLINGO_CORE_ONLY=1 swift test` for the core unit suite. This opt-in mode excludes
the app, SwiftData storage target, and persistence tests. Leave the variable unset for ordinary
development and all release checks.

### Verification on the development machine

The core library and validator compiled with Apple Swift 6.4 in Swift 5 language mode,
targeting arm64 macOS 14. The validator passed with all 60 cards. The full build stopped
because the installed command-line tools lack `SwiftDataMacros`; the unit test run also
stopped because they lack XCTest. **The full app and the 25 XCTest cases are not verified
on this machine.** Full Xcode 15+ is required to finish those checks. No GUI launch or
macOS 14 runtime test is claimed.

## Delivered

- 30 Everyday English and 30 Tech / Work English cards, all in editable bundled JSON.
- English/Turkish meanings, CEFR, part of speech, two marked examples, US/UK IPA,
  usage notes, and searchable tags ready for later UI.
- Versioned JSON Schema and validated content-only JSON encoding/decoding.
- SwiftData deck, card-progress, review-event, and preferences models.
- SM-2-based Again/Hard/Good/Easy scheduling with 1-minute and 10-minute short steps.
- Weighted due-first queue, daily budgets, leech flags, maturity, streak and retention helpers.
- UI-independent `LearningModule` protocol for future modules.
- XCTest coverage for scheduling, JSON parsing, seed integrity, statistics, and persistence.

## Structure

```text
Package.swift
Decks/                         # Canonical JSON copied into the resource bundle
Schema/deck.schema.json
Sources/NotchLingoCore/
  Content/                     # Portable DTOs, validation, JSON codec, seed loading
  Scheduling/                  # Pure SRS, queue, statistics
  Modules/                     # LearningModule contract
Sources/NotchLingoStorage/      # SwiftData models and main-actor store
Sources/NotchLingoApp/          # Minimal SwiftUI foundation window
Sources/NotchLingoValidate/     # Command-line content and scheduler smoke checks
Tests/NotchLingoCoreTests/
Tests/NotchLingoStorageTests/
docs/                          # Content contract and scheduling decisions
```

The core owns domain behavior, the storage target owns persistence, and the app owns presentation. MVVM view models
will be introduced with interactive modules, rather than wrapping the static Phase 1 view.
See [deck format](docs/DECK_FORMAT.md) for adding cards and the planned CSV contract,
and [scheduling](docs/SCHEDULING.md) for exact transitions and budget semantics.

## Platform decisions and risks

DynamicNotchKit offers an existing notch UI built around macOS panels, but a custom NSPanel
provides direct control over passive presentation, screen selection, and fallback behavior.
We choose the custom approach to keep focus handling explicit and avoid third-party dependencies.
Reference: [DynamicNotchKit source](https://github.com/mrkai77/DynamicNotchKit).

Notch position, Spaces, full-screen windows, display scaling, and external displays need real-device
verification in Phase 2. Passive pings must use a nonactivating panel and must not make it key;
only an explicit user action may enter a keyboard-driven session. Public APIs do not offer a
universal reliable Focus-state query, so future reminders need conservative notification-based
behavior and a manual pause, without promising automatic Focus detection everywhere.

Speech recognition is planned to require on-device recognition, with a clear unavailable state
when the device or language lacks support; it must not silently fall back to a server. Local TTS
voice availability varies and some voices require a system download. Transcript similarity can
highlight missing words but cannot reliably diagnose individual phoneme pronunciation.
CEFR and IPA content are editorial seed material and welcome review by language teachers.

SwiftData uses a model container for local persistence:
[Apple's documentation](https://developer.apple.com/documentation/swiftdata/modelcontainer).
The minimum deployment target is macOS 14; this checkout should also be tested with the
oldest supported Xcode before a release. There is no destructive migration fallback.

## Permissions and privacy

Phase 1 requests **no microphone, speech, or notification permission** and makes no network calls.
Later phases will explain and request microphone/speech access only when speaking practice starts,
and notification access only when reminders are enabled. Optional AI will be disabled by default;
its network use must be explicit, and keys will go in Keychain. No AI implementation is included yet.

## Screenshots

- [Placeholder: Phase 2 collapsed and expanded notch panel]
- [Placeholder: Phase 5 dashboard and deck browser]

See [CONTRIBUTING.md](CONTRIBUTING.md) and [LICENSE](LICENSE).
