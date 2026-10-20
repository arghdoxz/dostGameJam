# Implementation Status

Last updated: 2026-10-20 (Prompt 4: tutorial, simulated-player QA, fixes, demo video). The MVP is playable end to end with placeholder art and unbalanced numbers, and has an interactive tutorial. **No human has played it yet.** A simulated first-time player (synthesized mouse input through the real UI, run by Claude) has; see `docs/qa/PLAYTEST_REPORT.md`. Everything marked Verified is verified by executed tests or captured and viewed screenshots.

Legend: **Verified** = covered by tests that were executed (or screenshots viewed). **Implemented** = code exists, exercised only indirectly.

| System | Status |
|---|---|
| Godot project (`project.godot`, 4.7.2), autoload `ContentDB`, theme | Verified: imports and starts with no script errors |
| Definitions and generated `.tres` content (25 cards, 7 disasters, 7 buildings, 5 territories) | Verified (`test_content`) |
| Match/player state, seeded RNG, serialization of actions, replay | Verified (`test_deck`, `test_serialization`, `test_full_match`) |
| Validation: out of turn, wrong phase, unaffordable, stale/duplicate, self/eliminated target, after game over; rejection leaves state unchanged | Verified (`test_validation`, `test_edge_cases`) |
| Turn system, round counting, hand-limit discards | Verified (`test_victory`, `test_edge_cases`) |
| Deck system: draw, discard, reshuffle, exhaustion at turn draw and in draw effects | Verified (`test_deck`, `test_edge_cases`) |
| Payment (hand and Reserve) | Verified (`test_payment`) |
| Disasters: L1 immediate, L2/L3 forecasts, reaction windows, secondary effects, fizzles, chains with eliminations, ghost turns | Verified (`test_disaster`, `test_edge_cases`) |
| **Final-round forecasts resolve at the cap (R6)** | Verified (`test_final_round`, plus a mutation check: breaking it failed 5 tests) |
| Damage calculator, durability, wear, destruction, preview equals actual damage | Verified (`test_damage`, `test_preview`) |
| Elimination, three win conditions, tiebreaks, simultaneous elimination with pre-blow durability (R8) | Verified (`test_victory`) |
| Buildings, repair, heal, draw, extra play | Verified (`test_validation`, `test_disaster`, `test_edge_cases`) |
| `ActionEnumerator.explain` (why a card cannot be used) | Verified (`test_preview`) |
| `MatchController`: re-entrancy guard, `abandon()` during a Reaction window, clean restart | Verified (`test_edge_cases`, UI smoke) |
| Tabletop UI: board with seats around a central map, regions, building and forecast tokens, deck piles, hand fan, action panel, payment picker, disaster panel, resolution summary, event log, discard and leave/restart dialogs, pass-device cover, results screen | Layout verified by viewing captured screenshots at 1600x900 (2 and 4 players); logic verified by the UI smoke test (32 checks). Not verified: real mouse play, hover/click feel, other resolutions |
| Artist integration: `AssetLibrary` registry of 72 slots, correct-aspect placeholders, theme and font hooks, generated manifest, replacement docs | Verified (`test_assets`) |
| **Interactive tutorial** (menu button; 32 steps; hot-seat, learner plays both seats, fixed seed; Skip step, Restart, Exit; replay from the finish step) | Verified: `test_tutorial` (completable step by step), UI smoke (start, progress, restart, exit, no coach in a normal match), and a full replay through real clicks on the final build with all 41 shots reviewed |
| **QA driver and demo recorder** (`tools/qa_driver.gd`, `tools/record_demo.ps1`) | Verified by use: the QA screenshots and the demo video were made with them |
| **Demo video** `docs/demo/scratch-notes-development-demo.mp4` (3:05) | Verified with ffprobe and extracted frames; includes one captioned debug-assisted segment |
| Layout at 1280x720 and 1024x768, live resize, a 12-card hand | Verified by screenshots (`docs/qa/screenshots/small-windows/`) |
| Last-town-standing win in 2 players through the UI | Verified (debug-assisted setup, then real clicks) |
| Debug panel (F1) | Implemented, untested |
| Windows export | Not started (M5) |
| Networking | Out of scope |

## Latest validation run (2026-10-20, final build)
- `godot --headless --path . -s res://tests/run_tests.gd`: **121 passed, 0 failed**, exit 0, no `SCRIPT ERROR`.
- `godot --headless --path . -s res://tests/smoke_ui.gd`: **OK, 169 checks**, exit 0.
- `godot --headless --path . --quit-after 120`: starts, no script errors (only engine shutdown leak notices).
- Real-UI replays on the final build, no `SCRIPT ERROR`: the tutorial start to finish plus restart and exit; a full 2-player match played by the `auto` player to game over (round 10, last town standing; `audit`: 0 mismatches); the small-window pass; the last-standing win; the BUG-008 repro.
- Regression guards were mutation-checked (BUG-001, 004, 008, 010, 016: each test failed when its fix was removed).
- 13 bugs logged, 12 fixed, 1 open (BUG-012, not reproduced): [qa/BUGS_AND_FIXES.md](qa/BUGS_AND_FIXES.md).

## Not verified
Hands-on play by a person (mouse feel, hover animation, whether the tutorial teaches a real newcomer), real hot-seat flow with people, match length in minutes, balance, window sizes below 1024x768, DPI scaling, Windows export, the F1 debug panel, real artist assets and fonts. Card illustrations show through a 114x66 window (see `artist/ARTIST_HANDOFF.md`).
