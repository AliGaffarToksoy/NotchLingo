# Contributing

Use Xcode 15+ / Swift 5.9+ on macOS 14+. Open Package.swift in Xcode or use
`swift test` and `swift run NotchLingo` from this directory. There are no external dependencies. Full Xcode is required for SwiftData macros.
For domain-only smoke checks without it, run `NOTCHLINGO_CORE_ONLY=1 swift run NotchLingoValidate`.
If XCTest is available, `NOTCHLINGO_CORE_ONLY=1 swift test` runs the core unit suite. Neither
verifies the app or storage. Full tests must pass before release.

Keep scheduling logic pure and cover behavior changes with deterministic XCTest tests.
Keep persistence on the main actor, and keep content separate from review progress.
Use macOS 14-compatible public APIs. Never silently delete or reset a user's store.
Document schema changes and add a SwiftData migration plan before changing shipped models.

For content contributions, edit Decks/*.json, preserve existing UUIDs, and validate with
`swift test`. New cards need unique UUIDs, two or three natural examples, English and Turkish
meanings, IPA for both locales, CEFR, and tags. Mark the target phrase with **double asterisks**.
CEFR labels are editorial guidance, not official exam classifications. IPA is broad transcription;
please flag regional differences and errors. Submit original content or properly licensed material.

In pull requests, explain the user-visible change, testing, and any accessibility implications.
Do not commit personal learning data, signing credentials, keys, or generated build output.
