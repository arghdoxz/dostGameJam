# Screenshot Index

All files are real captures of the running game (1600x900 unless noted), saved by `tools/qa_driver.gd` with `shot <name>` and opened and inspected after capture. Nothing is mocked or edited. Folder: `docs/qa/screenshots/`.

**How each set was checked**
- Sets 01 to 58 and `bug-*`: captured during the interactive pass (one command at a time, each screenshot viewed before choosing the next click). Observations below are what I noted then.
- `regression-final/`: the same tutorial replayed on the **final build** by `docs/qa/scripts/tutorial_full_run.txt`. All 41 tutorial shots were reviewed in tiled contact sheets (readable text, no overlap, coach panel clear of the content it explains), plus four shots individually. Of the 24 `auto-*` shots of the final automatic match, 9 sampled shots were reviewed; the rest were not individually viewed (the driver's `audit` command compared the screen with the match state at the end: 0 mismatches).
- `small-windows/` and `60` to `64`: replays on the final build; each viewed individually or in the sheet noted.

"Mode" is **player** (only real clicks) or **debug** (the scene was set up with `debug_give` / `debug_rp`, then played by clicks).

## Menu and setup (player)
| File | State | Observation |
|---|---|---|
| 01-main-menu | Main menu | Three buttons, tutorial first. Placeholder background. |
| 06-setup-default | Setup, 2 players | Names, territory dropdowns, trait text, seed. |
| 06-setup-3-players | Setup after raising the count | A third row appears. |
| 06-setup-player-dropdown-open | Players dropdown open | Options 2 to 4. |
| 06-setup-territory-dropdown | Territory dropdown open | Five territories listed. |
| 06-setup-names-and-seed | Names and a seed typed | Typed text appears. |
| 06-setup-duplicate-territory-error | Same territory twice, Start pressed | Red "Territories must be distinct". |
| bug-008-before / bug-008-error-shown / bug-008-after | Setup error stays / is raised / clears when fixed | **BUG-008**. |

## Tutorial (player), first pass on the interim build
`02-tutorial-01-welcome` to `02-tutorial-32-finish` (plus `b`/`c` sub-shots), `03-tutorial-restart-fresh`, `04-tutorial-offscript-*` (early End Turn, cancelled discard, Skip step), `05-tutorial-exit-to-menu`. `interactive-passes/` keeps earlier attempts at the same steps. These show the tutorial before the BUG-002/005/016 fixes; use `regression-final/` for the current look.

## Tutorial (player), final build: `regression-final/`
One file per coach step, in order, each captured while the step shows (the green "OK - ..." line is the result of the previous action).

| Files | What they show |
|---|---|
| 01-main-menu, 02-tutorial-01 | Menu, then step 1 over the first hand-off cover ("Pass the device to Ana"). |
| 02-tutorial-02 to 05 | The table, the seat mat, the status bar, drawing. Outlines on the highlighted part. |
| 02-tutorial-06 to 09b | Select Seawall, read the panel, build it (token appears on the region), bank Supplies. |
| 02-tutorial-10, 11 | Select Barangay Drill (cannot be played, the panel says why), End Turn. |
| 02-tutorial-11b, 12 to 15 | Cover for Ben, disaster draw, select Landslide, pick a target, cast it. |
| 02-tutorial-16a to 17b | Reaction cover, reaction window, Go Bag chosen, cover back to Ben, "What happened" summary. |
| 02-tutorial-18, 18b, 19 to 22 | End turn, round 2, Typhoon selected and cast as a forecast, summary with the hazard token. |
| 02-tutorial-23 to 27 | Warning turn for Ben, forecast arrives, Pre-emptive Evacuation, summary of destruction. |
| 02-tutorial-28 to 32 | Round 3 draw, heal with Relief Operations, end-of-game rules, Log/Restart/Menu, "You're ready". |
| 03-tutorial-restart-fresh, 05-tutorial-exit-to-menu | Replay tutorial restarts from step 1; Exit tutorial returns to the menu. |

## Normal 2-player match (player): 07 to 28
| File | State | Observation |
|---|---|---|
| 07-normal-cover-first-player | First hand-off cover | Hand hidden. |
| 08-normal-initial-board | Start of match | Seats, regions, piles, hand fan. |
| 09-normal-after-draw | After drawing | Hand grows by one. |
| 10-normal-unaffordable-card-selected | Card that cannot be played | Panel gives the reason. |
| 11-normal-handoff-cover-dana, 12-normal-dana-turn | Turn change | Cover then the new hand. |
| 13-edge-target-without-disaster | Clicked a seat with no disaster selected | Nothing happens, no error. |
| 14, 15 | Landslide selected, target chosen via a map region | Predicted damage shown on the target. |
| 16, 17, 18 | Reaction cover, reaction window, resolution summary | Disaster panel shows the strike. |
| 19, 19b | Menu pressed mid-match | Confirm dialog; Cancel returns. |
| 20 to 22 | After chunks of the automatic player | Board stays consistent. |
| 23, 24, 25 | Game over board, results screen, rematch cover | |
| 26, 27, 28 | Restart confirm, fresh cover, back at the menu | |

## 4 players (player): 30 to 34
Setup with four rows, initial board with seats left/top/right, a disaster that hits all opponents selected, the cover before the first reactor, and the reaction window with three targets outlined.

## Elimination (debug: a town set to 1 RP): 35 to 39
Setup, lethal reaction window, cover, summary, and the hand-off that **skips** the eliminated player.

## Card text and payment (player): 40 to 43
Long name and cost on a card (BUG-009 after), payment picker, invalid selection (Confirm disabled), payment confirmed and a building built.

## Preparedness win and hand limit (debug: cards dealt): 50 to 58
Debug hand given, 3 Supplies banked, the two buildings built, the hand-limit discard dialog (one of two selected, then discarded), the win, game over board and results.

## Last-standing win in 2 players (debug: both towns at 1 RP): 60 to 64
Setup, target chosen, cover, reaction window, and game over: "GAME OVER: Last town standing. Winner(s): Mayor 1." (64 inspected: eliminated seat greyed, region marked ELIMINATED, banner "GAME OVER - View results").

## Automatic full matches (player: real clicks chosen by the driver's heuristic)
- `auto-001` to `auto-004`: earlier match.
- `regression-final/auto-001` to `auto-024`: the final-build match (ends in round 10 by last town standing). Every summary and reaction window along the way; the last is the game over board.

## Other window sizes (`small-windows/`)
| File | Size | Observation |
|---|---|---|
| 1280-01 to 1280-05 | 1280x720 | Menu, setup, board, draw, selected card: layout scales, nothing clipped. |
| 1280-06-big-hand | 1280x720 | 12 cards: all inside the hand area, hand count visible (BUG-014/015). |
| 1280-07 to 1280-09 | 1280x720 | Target chosen, reaction cover, reaction window with a big hand and disaster panel. |
| 1280-10, 1024-01 | 1280x720 then 1024x768 | Hand-off cover before and after a live window resize: stays centred. |
| 1024-02 to 1024-05 | 1024x768 | "What happened" summary, board with 11 cards, leave dialog, menu. |
| 1024-06, 1024-07 | 1024x768 | Tutorial welcome and step 4: coach panel top right, clear of the board. |

## Before/after pairs
`bug-001-before*` / `bug-001-after`, `bug-002-before` / `bug-002-after`, `bug-005-before` / `bug-005-after`, `bug-008-before` / `bug-008-after`, `bug-010-before` / `bug-010-after`. Details in [BUGS_AND_FIXES.md](BUGS_AND_FIXES.md).
