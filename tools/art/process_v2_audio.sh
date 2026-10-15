#!/usr/bin/env bash
# Convert generated v2 music/SFX (mp3) into project OGG files.
# Core (boot pack): title + stage 1 music and all SFX.
# Stage packs: stage 2/3 music, boss and victory music.
set -euo pipefail
cd "$(dirname "$0")/../.."
A=${ART_RAW_V2:?Set ART_RAW_V2 to the original v2 masters directory}/audio
C=assets/template/game/audio
mkdir -p $C assets/template/game/stage2 assets/template/game/stage3
music() { # in out
  ffmpeg -v error -y -i "$1" -af "loudnorm=I=-15:TP=-1.5:LRA=11" -ar 44100 -ac 2 -c:a libvorbis -q:a 3 "$2"
  echo "$2 $(wc -c < "$2")"
}
sfx() { # in out [extra filter]
  local f="silenceremove=start_periods=1:start_threshold=-50dB,areverse,silenceremove=start_periods=1:start_threshold=-55dB,areverse${3:+,$3},loudnorm=I=-14:TP=-1.0"
  ffmpeg -v error -y -i "$1" -af "$f" -ar 44100 -ac 1 -c:a libvorbis -q:a 4 "$2"
  echo "$2 $(wc -c < "$2")"
}
music $A/bgm_title.mp3 $C/bgm_title.ogg
music $A/bgm_stage1.mp3 $C/bgm_stage1.ogg
music $A/bgm_stage2.mp3 assets/template/game/stage2/bgm_stage2.ogg
music $A/bgm_stage3.mp3 assets/template/game/stage3/bgm_stage3.ogg
music $A/bgm_boss2.mp3 assets/template/game/stage3/bgm_boss.ogg
music $A/bgm_victory.mp3 assets/template/game/stage3/bgm_victory.ogg
# short stage-clear stinger cut from the fanfare opening (core)
ffmpeg -v error -y -i $A/bgm_victory.mp3 -t 5.5 -af "afade=t=out:st=4.3:d=1.2,loudnorm=I=-14:TP=-1.0" -ar 44100 -ac 2 -c:a libvorbis -q:a 4 $C/stage_clear.ogg
for n in ui_hover ui_confirm ui_pause rank_up rank_down fury_on fury_off chain_boom laser_charge laser_fire mg_nest missile overheat reel_zip tally_tick banner_slam gameover heartbeat panic; do
  sfx $A/$n.mp3 $C/$n.ogg
done
