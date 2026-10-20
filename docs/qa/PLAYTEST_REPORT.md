# Playtest Report

Date: 2026-10-20. Build: Godot 4.7.2, Windows, GL Compatibility, placeholder art. Related: [SCREENSHOT_INDEX.md](SCREENSHOT_INDEX.md), [BUGS_AND_FIXES.md](BUGS_AND_FIXES.md).

## What this is, and what it is not
I (Claude Code) played the game as a first-time player would, **through the real interface**: `tools/qa_driver.gd` boots the actual `App` scene in a real window and sends synthesized mouse presses, releases and key events at screen pixels, so Godot's own hit-testing, modal blocking and disabled buttons decide what a click does. It never calls `MatchController.submit`. After each step it saves a screenshot, which I opened and judged before choosing the next click.

This is **not human playtesting**. It cannot judge fun, pacing, balance, mouse feel, hover animation smoothness or how a real person misreads the screen. No human has played this build.

Commands that bypass the rules (`debug_give`, `debug_rp`, `debug_disaster`) exist only to reach rare states quickly. Runs that use them are labelled **debug-assisted** below. The `auto` command plays a match with a simple heuristic (build, heal, strike, bank, else end turn) but still only by real clicks; it is labelled **auto**.

## Scenarios played
| # | Scenario | Mode | Result |
|---|---|---|---|
| 1 | Menu, setup (player count, names, territories, seed, duplicate-territory error, Back) | player | Works. BUG-008 found and fixed. |
| 2 | Full tutorial, 32 steps, start to finish; Skip step; Restart; Exit; Replay from the menu | player | Completes. BUG-001, 002, 005, 016 found and fixed on the way. Re-run on the final build with no script errors. |
| 3 | Off-script behaviour inside the tutorial: End Turn too early, cancelling the discard dialog, Skip step | player | Tutorial recovers; wrong actions never complete a step. |
| 4 | Normal 2-player match: draw, unaffordable card, bank, build, Landslide with a target, reaction cover and window, summary, leave-confirm, restart-confirm | player | Works. |
| 5 | A 2-player match to its natural end, played several times | auto | Reaches game over (last standing in the final run, round 10). End-of-run `audit` found 0 mismatches between the screen and the match state. |
| 6 | Payment picker: open, invalid selection (Confirm disabled), confirm | player | Works. |
| 7 | 4-player setup, seating, all-opponents disaster, 3-target reaction window | player | Works. |
| 8 | Elimination during a reaction; hand-off skips the eliminated player | debug-assisted (RP set to 1) | Works. |
| 9 | Preparedness win (Evacuation Center, Early Warning, 3 Supplies); hand-limit discard dialog | debug-assisted (cards dealt) | Works. |
| 10 | Last town standing in 2 players | debug-assisted (both at 1 RP) | Works; banner, results. |
| 11 | Window sizes 1280x720 and 1024x768, live resize, a 12-card hand | player + debug-dealt hand | Layout holds. BUG-014, 015 found and fixed. |
| 12 | Results screen, rematch, new setup, main menu | player/auto | Works. |

Edge cases tried by clicking: unaffordable card, target click with no disaster selected, clicking End Turn during the Draw phase, double-clicking "Do not react" (guarded by a lock, covered by a smoke test), leaving mid-reaction.

## What the first-time-player pass changed
The tutorial was written to match the implemented rules and then played through the screen. That pass found that a long card description pushed the Play button off screen (so the tutorial's Typhoon step could not be completed), that the coach panel covered the text it explained, that the "last played" card covered building and forecast tokens, and that several texts were clipped or stale. All were fixed and re-played (see BUGS_AND_FIXES).

## Independent review
A read-only Sonnet review of the tutorial code, the driver and `LastPlayView` found no rules or card-handling bugs. It found, and I fixed: debug commands that logged success when they did nothing or ran with no match (they now error), debug commands that did not wait for the hand to rebuild (a false audit mismatch; they now wait 3 frames), `click_pile` accepting any word as "disaster", the deck-count audit accepting "11 cards" for "1 cards", and tutorial wording on which card pays for Relief Operations. Not fixed: clicks on disabled or covered buttons are logged with `disabled=true` rather than raised as errors (read the log), and `MatchController.export_log` does not record the tutorial's card arrangement, so an exported tutorial log would not replay exactly.

## Not tested
- Any human play, at any skill level. Understanding of the tutorial by a real new player.
- Real touch input, gamepads, Windows DPI scaling above 100 percent, multi-monitor.
- Fullscreen and window sizes below 1024x768.
- The F1 debug panel (implemented, untested).
- Windows export and running on a clean machine.
- Real artist assets and fonts (placeholders only), audio (none exists).
- Match length with humans (the automatic matches take 7 to 10 rounds, which says nothing about minutes).
- Balance. The automatic matches I watched ended by last town standing (rounds 7 and 10); whether that is typical is unknown.
- Intermittent behaviour: see BUG-012 (one ignored End Turn click seen once, not reproduced).

## Open issues
- BUG-012 (open, not reproduced).
- Cramped far-region note at 4:3 (see BUGS_AND_FIXES).

## Design questions for the rule makers (no rule was changed)
1. Is it intended that a Reaction window opens even when the reactor holds no Reaction card? It costs a click and a hand-off cover every time. (Chosen to keep hands hidden; DECISIONS lists it as an assumption.)
2. Hot-seat flow: every reaction needs a hand-off cover to the target and another back to the caster. Long matches have many covers. Consider whether the cover should be skippable when only two players are present.
3. Is 1 play per turn plus a free Reserve bank right for pacing? Many cards show "Not usable now" on a given turn; humans may find that frustrating or fine.
4. Should the preparedness-win rule (R4) require the three Supplies to still be in the Reserve at the start of the owner's turn? Currently yes. In the one debug run it was easy to reach once dealt the right cards; with normal draws it is untested.
5. Forecast timing: a forecast resolves at the start of the caster's next turn, so the target always has exactly one turn to prepare. Is that the intended warning gap for the DRR message?
