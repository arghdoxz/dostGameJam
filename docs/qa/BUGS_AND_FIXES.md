# Bugs and Fixes

Found by playing the game through the real UI (synthesized mouse input via `tools/qa_driver.gd`) as a first-time player would, 2026-10-20. Screenshot paths are relative to `docs/qa/screenshots/`.

IDs BUG-003, BUG-007 and BUG-013 were never filed (numbers skipped during live passes; there is nothing to report under them).

Regression guard column: **smoke** = `tests/smoke_ui.gd`, **unit** = `tests/unit/`. A guard is "mutation-checked" when I temporarily broke the fix and confirmed the test failed, then restored it.

| ID | Severity | Status | Found in | Guard |
|---|---|---|---|---|
| BUG-001 | Blocker | Fixed | tutorial / normal | smoke, mutation-checked |
| BUG-002 | Major | Fixed | tutorial | tutorial replay (visual) |
| BUG-004 | Minor | Fixed | cards, setup | unit, mutation-checked |
| BUG-005 | Major | Fixed | board | visual replay (before/after) |
| BUG-006 | Minor | Fixed | 4-player targeting | visual |
| BUG-008 | Minor | Fixed | setup | smoke, mutation-checked |
| BUG-009 | Minor | Fixed | hand | visual (shot 40) |
| BUG-010 | Major | Fixed | reaction window | smoke, mutation-checked |
| BUG-011 | Minor | Fixed | rejected actions | visual |
| BUG-012 | Minor | **Open, not reproduced** | normal match | none |
| BUG-014 | Major | Fixed | big hand | smoke |
| BUG-015 | Minor | Fixed | big hand | visual (small-windows shots) |
| BUG-016 | Minor | Fixed | board | smoke, mutation-checked |

## BUG-001 Long card text pushes the Play button off screen (Blocker)
- **Repro:** select a card with a long description and several pay options (Typhoon in the tutorial).
- **Expected:** the action buttons stay visible and the table does not move.
- **Actual:** the text grew the action panel, the Play button clipped or fell below the screen edge and the board above shifted. In the tutorial this made Typhoon impossible to cast.
- **Before:** `bug-001-before.png`, `bug-001-before-b-clipped-play-button.png`, `bug-001-before-c-layout-shift-and-offscreen-button.png`.
- **Cause:** the panel's description label and buttons shared one growing container.
- **Fix:** `scripts/ui/action_panel.gd`: description, preview and flavor sit in a scroll area that takes the spare space; buttons sit in a separate scroll of at most 3 rows; the "why not" line is outside the scroll.
- **Retest:** tutorial replay casts Typhoon (`02-tutorial-21-cast-typhoon.png`). **After:** `bug-001-after.png`.
- **Guard:** smoke `_step_long_card_*` (panel stays inside the screen; the board does not change height when selecting).

## BUG-002 Tutorial coach panel covered the action panel (Major)
- **Repro:** tutorial step 2 (the table), coach panel at the bottom right.
- **Actual:** the coach panel sat on top of the action panel, so both texts were unreadable (`bug-002-before.png`).
- **Fix:** the coach places itself at the top right and picks the position that overlaps the highlighted areas least (`tutorial_coach.gd`); panel background made opaque.
- **After:** `bug-002-after.png`; every step in `regression-final/02-tutorial-*.png` re-inspected on the final build.

## BUG-004 Raw ids shown to players (Minor)
- **Actual:** card and setup text showed tags like `storm_surge`.
- **Fix:** `CardText.tag_name/tag_list` (underscore to space, `*` to "all") used by cards and the setup screen.
- **Guard:** unit `test_card_text.gd` (mutation-checked: returning the raw tag fails both tests).

## BUG-005 "Last played" card covered the map (Major)
- **Actual:** the card and its text sat at the map centre and overlapped the near region's building tokens and forecast markers (the text "...phoon" spilled out under a forecast marker).
- **Fix:** new `scripts/ui/last_play_view.gd`, a small card plus text at the top-left of the table, outside the map. `MapView` no longer draws it.
- **Before / after:** `bug-005-before.png` / `bug-005-after.png` (same tutorial step on the old and new build).
- **Guard:** smoke checks `BoardView.last_play.shown_card()` (see BUG-010).

## BUG-006 Target hint clipped on seat cards (Minor)
- **Actual:** "CAN TARGET: 2-3 damage (click to target)" was cut off.
- **Fix:** `seat_view.gd` shows the hint alone, and "Click to target" only when there is no hint.

## BUG-008 Stale setup error (Minor)
- **Repro:** set two players to the same territory, press Start Match ("Territories must be distinct"), then change a territory.
- **Actual:** the error stayed after the problem was fixed (`bug-008-before.png`).
- **Fix:** `match_setup.gd` clears the error when rows or traits change.
- **After:** `bug-008-error-shown.png` then `bug-008-after.png` (replay `docs/qa/scripts/bug008_setup_error.txt`).
- **Guard:** smoke `_step_setup_error_clears` (mutation-checked).

## BUG-009 Long card names and costs clipped on the card (Minor)
- **Actual:** "Cost: 2 funds, 2 materials" and long names were cut on the card face.
- **Fix:** `card_view.gd`: name 12 px, cost label wraps in a 32 px box.
- **After:** `40-card-long-name-and-cost-selected-bug009-after.png`.

## BUG-010 Stale card in the reaction window (Major)
- **Repro:** a forecast cast turns earlier arrives; the last played card shown was an unrelated one.
- **Fix:** `match_screen.gd` sets the shown card and text from `disaster_revealed`.
- **Before / after:** `bug-010-before.png` / `bug-010-after.png`.
- **Guard:** smoke `_step_forecast_arrives_*`. The first version of the test did not fail on the mutant (an immediate disaster coincides with the last card), so a forecast-arrives scenario was added; that version fails on the mutant.

## BUG-011 Rejection message hard to see (Minor)
- **Fix:** the status line ("Not allowed: ...") uses a warm accent colour (`match_screen.gd`).

## BUG-012 Intermittent ignored End Turn click (Minor, OPEN)
- **Seen:** once, during an interactive pass, an End Turn click had no effect.
- **Status:** not reproduced in later replays (the tutorial replay and the full automatic match use End Turn dozens of times without a miss). Possibly the click landed while the header was disabled during a transition. No fix made and no guard written. Needs a human to watch for it.

## BUG-014 Big hand clipped at the screen edge (Major)
- **Actual:** with 10+ cards the outer, tilted cards were cut off by the screen edge or ran under the action panel.
- **Fix:** `hand_fan.gd`: `TILT_MARGIN` keeps room for the tilted corners; step is computed from the available width.
- **After:** `small-windows/1280-06-big-hand.png` (12 cards at 1280x720), `1024-03-board.png` (11 cards at 1024x768).
- **Guard:** smoke `_step_big_hand_*`.

## BUG-015 Lifted card covered the hand count (Minor)
- **Actual:** a selected card at the left end covered "Mayor 2's hand: N card(s), limit 7".
- **Fix:** `hand_fan.gd` raises the title above the cards (`z_index`).
- **After:** `small-windows/1280-06-big-hand.png`.

## BUG-016 Seat card taller than its slot covered the far region's title (Minor)
- **Actual:** seat cards need 135 px but the slot was 116, so the top seat covered the first line of the far town region ("Upland: Ben" half hidden; see `bug-005-before.png`).
- **Fix:** `SeatView.SEAT_SIZE` height 116 to 136.
- **After:** `small-windows/1024-03-board.png`, `1280-06-big-hand.png` (title fully visible).
- **Guard:** smoke checks every seat's minimum height against `SEAT_SIZE` (mutation-checked: 116 fails with "seat 0 needs 135 px").

## Known remaining rough edges (not bugs in the rules; for the artist or next developer)
- In a 2-player game the far region's note (for example "HIT -3, RP 17") sits on top of its Town Hall token at 4:3 window sizes; readable but cramped.
- The elimination log line starts with the ASCII marker "XX" and warnings with "!!" (deliberate placeholders for icons).
- Menus and the card art are placeholders; see `docs/artist/ARTIST_HANDOFF.md`.
