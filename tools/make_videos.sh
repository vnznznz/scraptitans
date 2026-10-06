#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
frames=build/video
out=release/marketing
rm -rf "$frames"
godot --path . --display-driver x11 --audio-driver Dummy --fixed-fps 60 --disable-vsync --resolution 360x540 -- --scenario video --shots "$frames"
mkdir -p "$out/videos" "$out/screenshots"

clip() {
	echo "-framerate 60 -start_number $2 -t $3 -i $frames/$1_%04d.png"
}

band() {
	echo "crop=360:203:0:$1,scale=1920:1083:flags=neighbor,crop=1920:1080:0:0,setsar=1"
}

encode=(-r 60 -c:v libopenh264 -b:v 10M -pix_fmt yuv420p -an -movflags +faststart)
tall="scale=1080:1620:flags=neighbor,setsar=1"

ffmpeg -y -loglevel error -loop 1 -framerate 60 -t 0.7 -i "$out/covers/portrait.png" \
	$(clip pile 12 2.3) $(clip build 4 5.4) $(clip mid 24 3.2) $(clip late 10 2.2) $(clip nuke 0 4.8) \
	-filter_complex "[0]$tall[a];[1]$tall[b];[2]$tall[c];[3]$tall[d];[4]$tall[e];[5]$tall[f];[a][b][c][d][e][f]concat=n=6" \
	"${encode[@]}" "$out/videos/portrait.mp4"

ffmpeg -y -loglevel error -loop 1 -framerate 60 -t 0.7 -i "$out/covers/landscape.png" \
	$(clip pile 12 1.7) $(clip build 4 4.8) $(clip build 292 1.2) $(clip mid 24 3.2) $(clip late 10 2.2) $(clip nuke 0 4.1) \
	-filter_complex "[0]setsar=1[a];[1]$(band 140)[b];[2]$(band 328)[c];[3]$(band 0)[d];[4]$(band 0)[e];[5]$(band 234)[f];[6]$(band 0)[g];[a][b][c][d][e][f][g]concat=n=7" \
	"${encode[@]}" "$out/videos/landscape.mp4"

for shot in factory:build_0200 first_mech:build_0345 battle:mid_0110 army:late_0060 nuke:nuke_0200; do
	ffmpeg -y -loglevel error -i "$frames/${shot#*:}.png" -vf "$tall" "$out/screenshots/${shot%%:*}.png"
done
