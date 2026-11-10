# macOS design revision

This is an independent app informed by Apple's Human Interface Guidelines, not an Apple product.

## References and decisions

- [Panels](https://developer.apple.com/design/human-interface-guidelines/panels): keep supplementary UI unobtrusive, compact, and sparing with color. The notch now measures its content rather than claiming a fixed 710-point height. Its SwiftUI tree remains mounted during resizing so typing state is retained.
- [Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars): a small set of standard commands, clear grouping. The main window has a native unified toolbar, source-list navigation, and one Study action.
- [Materials](https://developer.apple.com/design/human-interface-guidelines/materials): materials establish functional hierarchy rather than decorative layers. The main window uses semantic system surfaces and follows Light/Dark appearance; the notch blends with physical camera hardware and reduces transparency when requested. No fake Liquid Glass on content cards, and no macOS 26-only API dependency.
- [Typography](https://developer.apple.com/design/human-interface-guidelines/typography): system SF, body text near 13–15pt, regular/medium/semibold weights, sparse emphasis. Secondary controls remain at or above the macOS 10pt minimum.
- [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility): meaningful labels, native keyboard navigation, textual feedback alongside color, Reduce Motion and Reduce Transparency handling.

## Notch behavior

Collapsed: camera-safe wings show an unobtrusive symbol and the word of the day (or session timer).
Hover provides the full bilingual term; clicking or the global shortcut expands the session.

Expanded: 440pt width, camera safe area, a quiet title/action row, and content-measured height.
Height is capped to the available display area; long content scrolls. The top edge stays anchored
while the lower edge changes over 240ms. Reduce Motion switches to immediate resizing.
Definitions and one example appear after reveal; extra examples/notes use progressive disclosure.
Review actions stay consistent in order and shape, with one visual emphasis on Good.

Passive quizzes never become key. Only an explicit action opens a typing-capable session.
The panel persists across Spaces as a utility, a deliberate difference from a window-specific inspector.

## Main window

Native sidebar and toolbar; semantic background colors; one teal accent. The main content prioritizes
today's progress, the word of the day, and a short session. Goals, library state, and activity remain
secondary. Empty states explain what appears after learning instead of showing unexplained blanks.
No duplicated live exercise competes with the notch in the dashboard.

## Verification

Inspect the actual packaged app in both languages, measure collapsed/expanded frames, check the reveal
transition, inspect long examples and settings at the minimum window width, and verify keyboard actions.
Automated domain/import tests remain mandatory before packaging. Microphone recognition availability,
Focus suppression of system notifications, and multiple-display behavior require device-specific tests.
