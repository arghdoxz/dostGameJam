# Testing Strategy

Framework: a small custom runner (`tests/run_tests.gd`, no addon; GUT was dropped on 2026-10-20). Test classes extend `tests/test_case.gd`. The rules core is pure `RefCounted`, so almost everything is testable headless.

## Command
```
godot --headless --path . --import                       # once, or after adding class_name scripts
godot --headless --path . -s res://tests/run_tests.gd    # all tests, exit code 0 on success
godot --headless --path . -s res://tests/run_tests.gd -- test_damage   # one file
godot --headless --path . -s res://tests/smoke_ui.gd     # boots App, plays a match through the UI screens
godot --headless --path . -s res://tools/generate_content.gd  # regenerate content .tres
godot --headless --path . -s res://tools/generate_asset_manifest.gd  # regenerate assets/ASSET_MANIFEST.md
godot --path . -s res://tools/capture_screens.gd -- C:/some/folder  # screenshots; needs a real window, not --headless
godot --path . -s res://tools/qa_driver.gd -- --script docs/qa/scripts/tutorial_full_run.txt --shots C:/some/folder   # replay a real-click session
```
On Windows call the full Godot executable (for example through `Start-Process -Wait`) if the `godot` shim prints nothing.
Expected: `Tests passed: N, failed: 0`, exit code 0. A test that aborts on a runtime error prints a `SCRIPT ERROR`; also grep the output for `SCRIPT ERROR` because the runner cannot catch those. Missing-art warnings from `AssetLibrary` are expected until final art exists.

## Unit tests (`tests/unit/`)
- **Damage calculator:** the flood example (5 - 3 - 1 = 1); damage never below 0; territory modifiers; reaction reductions; durability loss (1, or 2 vs. L3); destruction at 0.
- **Validation:** out-of-turn play, unaffordable card, self-target, eliminated target, second play, reaction outside a window. State must be unchanged after a rejected action.
- **Deck system:** draw, discard, reshuffle when empty, both decks empty.
- **Disaster resolver:** L1 immediate; L2/L3 become forecasts; forecast order; forecasts fizzle on eliminated targets; condition targeting with no matches.
- **Victory evaluator:** last standing; round-cap winner; every tiebreak; preparedness win; simultaneous elimination.
- **Content:** every definition loads, ids are unique, every `art_id` has a placeholder, every disaster references a valid definition.
- **Serialization:** each `GameAction` round-trips through `to_dict()` / `from_dict()`.
- **Final round (`test_final_round`):** forecasts resolve at the cap with Reaction windows, in cast order, can eliminate and end the match, fizzle cleanly, and a match without forecasts scores at once.
- **Edge cases (`test_edge_cases`):** draw effects on empty decks, exhausted turn draw, unaffordable card, fizzled disaster paying once, eliminated targets, building destroyed then secondary damage, forecast chain with an elimination, ghost turn of an eliminated caster, duplicate/stale/out-of-turn/wrong-phase actions, hand-limit discards, no actions after game over, `abandon()` during a Reaction window and clean restart, re-entrant submit.
- **Preview and explain (`test_preview`):** UI damage previews equal actual damage (with buildings, territory and reactions); `ActionEnumerator.explain` reasons agree with the legal action list.
- **Assets (`test_assets`):** every content and UI slot resolves; manifest rows match `AssetLibrary` paths; placeholders keep aspect ratio; missing-file and missing-font fallbacks; no hard-coded `res://assets/` paths in game scripts.

- **Tutorial (`test_tutorial`):** the scenario arranges the stacked hands without creating or losing cards and with unique uids; every step is well formed; the whole 32-step lesson can be completed step by step through `RulesEngine` (so it can never get stuck); wrong actions never complete a step.
- **Card text (`test_card_text`):** tags are shown without underscores (BUG-004), checked on every card.

## Integration tests (`tests/integration/`)
- A seeded scripted match from setup to game over. The same seed and action list must produce identical final state (determinism and replay).
- A 2-player and a 4-player run.

## UI smoke test (`tests/smoke_ui.gd`)
Boots the real `App` scene and drives it headless: setup screen, board layout (acting player at the near seat, one map region per player, one card view per card in hand), a bot to a Reaction window (disaster panel visible), leave-confirm mid-reaction (returns to menu, match abandoned), fresh restart, the payment picker (invalid payment disables Confirm, auto-select restores, confirm submits the play), a bot to game over, results screen, rematch, 4-player seating, the tutorial (start from the menu, progress, restart, exit; a normal match has no coach), the Disaster panel double-click lock, and regression checks for BUG-001 (long card text), BUG-008, BUG-010, BUG-014 and BUG-016. It cannot judge looks.

## Real-UI QA driver (`tools/qa_driver.gd`)
Plays the real game in a real window with synthesized mouse and keyboard input, so Godot's own hit-testing, modals and disabled buttons apply. It needs a display (not `--headless`). The full command list is at the top of the file.
- Interactive: `godot --path . -s res://tools/qa_driver.gd -- --io <dir>`; write commands to `<dir>/cmd.txt`, read `<dir>/out.txt`.
- Replay: `-- --script <file> --shots <dir>`. Saved sessions in `docs/qa/scripts/`: `tutorial_full_run.txt` (the whole tutorial plus restart and exit), `normal_match_auto.txt` (a complete 2-player match with the `auto` player), `small_windows.txt` (1280x720 and 1024x768), `last_standing_win.txt` and `bug008_setup_error.txt`.
- Commands starting `debug_` bypass the rules; label any run that uses them "debug-assisted".
- `audit` compares what the screen shows with the match state and prints mismatches. `dump` prints what a player can see.
- Demo video: `tools/record_demo.ps1` (see `docs/demo/DEMO_NOTES.md`).
This is how the screenshots in `docs/qa/screenshots/` were made (index: `docs/qa/SCREENSHOT_INDEX.md`). It is not a substitute for human play.

## Manual checks (cannot be automated here)
Do these in a real window; each takes a minute or two.
1. **2 players:** start a match, draw, play a building (open "Choose payment..." once), bank Supplies, end turn with more than 7 cards and confirm the discard dialog; check the pass-device cover hides the hand each turn change.
2. **Disaster:** play a Disaster card; check the damage preview on the target seat, the disaster panel during the Reaction window, the red region outline with "STRIKE", and the "What happened" summary afterward.
3. **4 players:** check the three opponents sit left, top and right, a single-target Disaster can be aimed by clicking a seat or a map region, and the preview appears on every affected town.
4. **Leave/restart mid-reaction:** during a Reaction window press Restart and Menu; both ask for confirmation, then start a clean match or return to the menu.
5. **Missing art:** the game already runs with every asset missing; drop one PNG from the manifest into place and confirm only that slot changes.
6. **Match length:** time a complete 4-player match (target 20 to 30 minutes) and log it in DECISIONS.md for the rule makers.
