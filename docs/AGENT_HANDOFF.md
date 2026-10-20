# Agent Handoff: Prompt 5 Start Here

Prompt 4 made the game teachable and tested it through the real UI. The local 2 to 4 player hot-seat MVP has an in-game tutorial, was played by a simulated first-time player (Claude, synthesized mouse input; not a human), had 12 bugs fixed with regression guards, and has a demo video, an artist handoff and a QA record. It is **still not balanced and no human has played it**.

## Read first
1. [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md): what is verified, how, and what is not.
2. [qa/PLAYTEST_REPORT.md](qa/PLAYTEST_REPORT.md) then [qa/BUGS_AND_FIXES.md](qa/BUGS_AND_FIXES.md): what the simulated player found, what it could not judge, and the one open bug (BUG-012).
3. [DECISIONS.md](DECISIONS.md): approved rules (R1 to R9, UI1, T1 to T4) and the open questions for the rule makers.
4. [TECHNICAL_ARCHITECTURE.md](TECHNICAL_ARCHITECTURE.md): see "Prompt 3 additions" and "Prompt 4 additions" (tutorial, QA driver).
5. [artist/ARTIST_HANDOFF.md](artist/ARTIST_HANDOFF.md), [ART_PIPELINE.md](ART_PIPELINE.md), [../assets/ASSET_MANIFEST.md](../assets/ASSET_MANIFEST.md) for art.
6. `CLAUDE.md`: subagents must be `sonnet` or `haiku`; run tests only after implementing.

## Environment and commands
Godot 4.7.2. No GUT: custom runner. Run `--import` first on a fresh clone and after adding any `class_name` script. On this Windows machine the `godot` shim printed nothing; run the full executable (for example via `Start-Process -Wait` with redirected output).
```
godot --headless --path . --import
godot --headless --path . -s res://tests/run_tests.gd            # 121 tests; exit 0; also grep for "SCRIPT ERROR"
godot --headless --path . -s res://tests/smoke_ui.gd             # 169 UI checks through the real App
godot --path . -s res://tools/qa_driver.gd -- --script docs/qa/scripts/tutorial_full_run.txt --shots <dir>   # real clicks; needs a window
powershell -File tools/record_demo.ps1                           # demo video (needs GODOT and ffmpeg)
godot --headless --path . -s res://tools/generate_content.gd     # rewrites content/*.tres
godot --headless --path . -s res://tools/generate_asset_manifest.gd
godot --path .                                                    # play (F1 = debug panel)
```
Autoloads (like `ContentDB`) are not visible to scripts run with `-s`; use `root.get_node("ContentDB")`. Do not run two Godot instances that write the same output file at once.

## Entry points
| Path | Role |
|---|---|
| `scenes/boot/app.tscn`, `scripts/app.gd` | Main scene; screen swapping, owns the `MatchController`; `start_match`, `start_tutorial` |
| `scripts/match_controller.gd` | UI to engine bridge: `submit`, `abandon`, `legal_actions`, signals, `start(..., prepare)` |
| `scripts/core/rules_engine.gd` | `new_match`, `start_match`, `validate`, `apply`: the only state mutators |
| `scripts/core/*.gd` | Static rule systems |
| `scripts/defs/`, `content/`, `tools/generate_content.gd` | Typed definitions and generated data (all numbers) |
| `scripts/ui/match_screen.gd` | Composes the tabletop |
| `scripts/tutorial/` | Tutorial: scenario, steps, script (32 steps), coach overlay |
| `tools/qa_driver.gd` | Real-click QA driver, recorder target |
| `scripts/ui/asset_library.gd` | The only code that knows asset paths |
| `tests/` | `run_tests.gd`, `unit/` (includes `test_tutorial.gd`, `test_card_text.gd`), `integration/`, `smoke_ui.gd` |

## What the tutorial is
A fixed-seed (4242) hot-seat match where one learner plays Ana (Coastal) and Ben (Upland) with stacked hands. `TutorialScenario.arrange` only moves cards. Each `TutorialStep` has a completion predicate over a `TutorialContext`; ACTION steps always offer Skip step. `TutorialCoach` is added to the match screen by `App.start_tutorial()` only. If you change a card's cost, effect or id used by the lesson, `test_tutorial` fails; update `tutorial_scenario.gd` / `tutorial_script.gd`, then replay `docs/qa/scripts/tutorial_full_run.txt` and look at the shots. If you change the layout, replay it too: the coach outlines use `MatchScreen.highlight_rects`.

## Working lessons from Prompt 4
- Real play found what tests did not: BUG-001 would have made the tutorial impossible to finish and no test noticed. Replay the saved sessions in `docs/qa/scripts/` after any UI change and look at the screenshots; do not trust the smoke test for looks.
- Prove a regression test by breaking the fix and watching it fail (the BUG-010 test first passed on the broken code).
- Headless runs have a different visible rect than a window; keep tolerances for 1 px differences.
- Windowed Godot is needed for screenshots; `--headless` returns blank images.

## Known bugs and limits
- **BUG-012 (open):** one End Turn click was ignored once in an interactive pass; not reproduced. Watch for it in human play.
- **No human playtest.** Mouse feel, hover, readability over time, tutorial comprehension, balance and match length are unknown.
- Layout was verified at 1600x900, 1280x720 and 1024x768, not below. Token rows overflow their map region if a town owns more than about 5 buildings (the Town Hall token counts); this was not re-tested in Prompt 4. The far region's note is cramped at 4:3.
- Card art shows through a 114x66 window cropped from portrait art; icons and `seat_mat` slots are not drawn by any screen yet (see ARTIST_HANDOFF).
- `MatchController.export_log` records only the seed and seats, not `TutorialScenario.arrange`, so an exported tutorial log does not replay exactly.
- The QA driver logs a click on a disabled or covered button with `disabled=true` instead of failing; read its output, not just the exit code.
- Payment is automatic by default (`Payment.auto_pay`) with an optional picker.
- Balance: all numbers and the deck composition (62 Town cards, 17 Disaster cards) are first-pass. DRR tip text is placeholder.
- The headless runs print "ObjectDB / resources still in use at exit" notices from engine shutdown.
- Windows export not attempted. F1 debug panel untested. No audio, pause or save/load.

## Unresolved rules (rule makers)
See "Open questions" in DECISIONS.md. New this round: reaction windows when no Reaction card is held, pacing of 1 play per turn, the one-turn forecast warning gap, and the card art window. Nothing blocks play.

## Recommended next steps (Prompt 5)
1. Put the build in front of **real people**: the tutorial with someone who has never seen the game, then a 2 and a 4 player match with the rule makers. Record minutes per match, where people hesitate and what they misread. This is the largest known gap.
2. Fix what that finds; keep `docs/qa/scripts/` replays and add a replay for each fixed bug.
3. Tune numbers in `tools/generate_content.gd` with the rule makers; verify the preparedness win can occur in normal play.
4. Get first art in and decide the card art window (large card preview or new layout); wire the icons and seat mat if wanted.
5. Windows export (M5) and a run on a clean machine.
6. Only then: the networking work, using the requirements in PROJECT_PLAN.md "Future multiplayer requirements".

## Do not rewrite without reason
- The `validate`/`apply`/events boundary and `GameAction` serialization.
- Seeded RNG: always `state.rng` inside `scripts/core/`, never global `randi()`.
- Data-driven content; `ContentCatalog` injection; asset paths only in `AssetLibrary` (a test enforces it).
- The tutorial must not add rules or special-case the engine: it only arranges the starting hands.

## Must still NOT implement
Networking, RPCs, lobbies, accounts, matchmaking, AI opponents, votes or political office, board movement, final art, rules not in the docs.
