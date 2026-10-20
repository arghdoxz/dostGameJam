# Demo Notes

## What the video is
A real recording of the game, not an animation or a mock-up. Godot's Movie Maker (`--write-movie`, fixed 30 fps) renders every frame of the running game while `tools/qa_driver.gd` plays it with synthesized mouse clicks. ffmpeg converts the AVI (MJPEG) to H.264 MP4. Nobody operated the mouse; the click list is `docs/demo/demo_commands.txt`.

## Real versus scripted
- **Real:** the tutorial run (all 32 steps, plus Replay tutorial and Exit tutorial), the menu, setup, every rule outcome shown (damage, forecasts, reactions, summaries, game over, results). All come from the game's own code.
- **Scripted:** the pacing (`wait` frames between clicks) and the captions.
- **Debug-assisted (and captioned as such):** in the normal match the demo gives each player a Landslide card and sets both towns to 1 RP (`debug_give`, `debug_rp`) so the match can end in seconds. These two commands bypass the rules; everything after them (select, target, cast, react, game over) is ordinary play through clicks.
- **Not a human playthrough.** No person played this build; see [../qa/PLAYTEST_REPORT.md](../qa/PLAYTEST_REPORT.md).

## Known blemishes in the video
- The caption bar sits over the bottom edge of the screen and sometimes covers the lowest line of the action panel (about 0:25).
- The video has a silent AAC track (the game has no audio).
- All art is placeholder.

## Verification done
`ffprobe` on the mp4: H.264, 1600x900, 30 fps, 185.4 s, 4.97 MB. Frames extracted at 3, 25, 50, 80, 110, 140, 160, 170 and 178 s and viewed: menu, tutorial build step, Landslide targeting, round 2, forecast arrival and Pre-emptive Evacuation, menu after the tutorial, targeting in the normal match, the game over summary and the results screen.

## Re-recording
1. Install ffmpeg (`winget install Gyan.FFmpeg`) and Godot 4.7.2.
2. `$env:GODOT = "<path to Godot_v4.7.2-stable_win64.exe>"; $env:FFMPEG = "<path to ffmpeg.exe>"` (FFMPEG is optional if ffmpeg is on PATH).
3. `powershell -File tools/record_demo.ps1`

A window opens and plays by itself; do not touch the mouse. Rendering takes several minutes (it is not real time, and the intermediate AVI is about 0.6 GB in your temp folder). To change what is shown, edit `docs/demo/demo_commands.txt` (`caption <text>`, `wait <frames>`; command list at the top of `tools/qa_driver.gd`). Waits are frames at 30 fps, and clicks need enough frames for animations to finish.
