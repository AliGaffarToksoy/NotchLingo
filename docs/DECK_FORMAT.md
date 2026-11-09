# Deck format v1

`Schema/deck.schema.json` is a JSON Schema 2020-12 document. `Decks/everyday.json`
and `Decks/tech-work.json` are complete editable examples and the actual bundled resources.
The Swift `DeckCodec` checks the same required content plus cross-field constraints.
Unknown JSON fields are ignored for forward-compatible metadata; unknown versions are rejected.

A deck has `schemaVersion: 1`, a stable UUID `id`, `name`, `track` (`everyday` or `techWork`),
and a nonempty `cards` array. Every card has a globally unique, stable UUID, `term`,
`partOfSpeech` (free text), `cefr` (A1/A2/B1/B2/C1), `definition` (simple English),
`turkishMeaning`, 2–3 `examples`, `ipaUS`, `ipaUK`, and a nonempty unique `tags` array.
`note` is optional and may be null. Required strings must contain non-whitespace text.
IPA uses broad dictionary-style transcription; it does not drive TTS. TTS will speak `term`.

Examples use **double asterisks** around the exact target phrase, case-insensitively.
Every example must contain a marked target, with balanced delimiters. Multiple marked
occurrences are allowed, but each must match the term. This avoids ambiguous substring
highlighting. Use the base form in a sentence where it fits naturally.

To add a seed card, copy a card object, generate a UUID with `uuidgen`, replace all content,
and run `swift test`. Rebuild the app: the new card is added on launch. Seeding does not
replace existing stored content or progress. During development, use a fresh test store to
check changes to existing seeds; do not delete personal progress. A content-update/import
workflow will be implemented in Phase 5. Keep IDs stable across content revisions.

JSON export is content-only. Scheduler state and review history are local records, not
part of a shared deck. `DeckCodec.encode`/`decode` support round trips now; file selection,
merge policy, cross-deck conflict resolution, and user import/export arrive in Phase 5.
Within-document duplicate IDs are rejected now; imports must also reject IDs owned by another deck.

## CSV contract reserved for Phase 5

CSV is UTF-8, comma-separated, RFC 4180 quoting (embedded quotes doubled), with a header:

```csv
schemaVersion,deckID,deckName,track,id,term,partOfSpeech,cefr,definition,turkishMeaning,example1,example2,example3,ipaUS,ipaUK,note,tags
```

One card per row; deck metadata repeats on each row and must agree for a given deckID.
`example3` and `note` may be empty. `tags` contains a JSON string array inside a properly
quoted CSV cell; this preserves commas and punctuation in tags without a second delimiter.
Example: the logical value `["daily","meeting"]` is written as `"[""daily"",""meeting""]"`.
Newlines and commas inside text must be quoted. CSV parsing/export is deliberately not
implemented in Phase 1; tests here cover the delivered JSON codec.
