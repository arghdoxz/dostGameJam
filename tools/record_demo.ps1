# Records the development demo: Godot Movie Maker (30 fps, real window) driven by qa_driver, then
# converts the AVI to H.264 MP4 with ffmpeg. Usage: powershell -File tools/record_demo.ps1
# Needs GODOT (path to the Godot 4.7 exe) and ffmpeg on PATH or FFMPEG set.
param(
	[string]$Godot = $env:GODOT,
	[string]$Ffmpeg = $(if ($env:FFMPEG) { $env:FFMPEG } else { "ffmpeg" }),
	[string]$Avi = "$env:TEMP\scratch-notes-demo.avi",
	[string]$Out = "docs/demo/scratch-notes-development-demo.mp4"
)
if (-not $Godot) { throw "Set GODOT or pass -Godot <path to the Godot executable>" }
& $Godot --path . --write-movie $Avi --fixed-fps 30 --resolution 1600x900 -s res://tools/qa_driver.gd -- --script docs/demo/demo_commands.txt --shots "$env:TEMP\demo-shots"
& $Ffmpeg -y -i $Avi -c:v libx264 -pix_fmt yuv420p -crf 23 $Out
