#!/usr/bin/env bash
# v2 sprite sheets (UI kit, VFX, props, stage decor) + environments.
# Adds sheets next to the v1 output of process_all.sh (does not delete it).
set -euo pipefail
cd "$(dirname "$0")/../.."
S=tools/art/slice_sheet.py
A=${ART_RAW_V2:?Set ART_RAW_V2 to the original v2 masters directory}
O=assets/template/game/sprites
T=/tmp/v2_alpha
mkdir -p $T
python3 tools/art/black_to_alpha.py $A/vfx_add_a.png $T/vfx_add_a.png
python3 tools/art/black_to_alpha.py $A/vfx_add_b.png $T/vfx_add_b.png
rm -rf $O/ui_portrait $O/ui_rank $O/ui_bar $O/ui_plate $O/ui_weapon $O/ui_banner $O/vfx_a $O/vfx_b $O/vfx_c $O/props2 $O/decor_canyon $O/decor_fortress
python3 $S $A/hud_portraits.png --cols 3 --rows 1 --names normal,hurt,fury --out $O/ui_portrait --target-height 200 --scale-ref max --anchor center
python3 -c "from PIL import Image; im=Image.open('$A/hud_ranks.png'); im.crop(im.getchannel('A').point(lambda v: 255 if v>40 else 0).getbbox()).save('$T/hud_ranks.png')"
python3 tools/art/split_row.py $T/hud_ranks.png $O/ui_rank D,C,B,A,S --height 220
python3 $S $A/hud_bars.png --cols 1 --rows 3 --names health,fury,boss --out $O/ui_bar --target-height 150 --scale-ref boss --anchor center
python3 $S $A/hud_plates.png --cols 3 --rows 2 --names weapon,score,slot,slot_hi,button,button_hi --out $O/ui_plate --target-height 130 --scale-ref slot --anchor center
python3 $S $A/hud_weapons.png --cols 5 --rows 1 --names pistol,hmg,spread,rocket,mg --out $O/ui_weapon --target-height 110 --scale-ref max --anchor center
python3 $S $A/banners.png --cols 1 --rows 3 --names win,lose,neutral --out $O/ui_banner --target-height 190 --scale-ref max --anchor center
python3 $S $T/vfx_add_a.png --alpha 6 --cols 4 --rows 2 --names flash_pistol,flash_hmg,flash_spread,spark_burst,hit_x,sparkle,latch,glint --out $O/vfx_a --target-height 200 --scale-ref max --anchor center
python3 $S $T/vfx_add_b.png --alpha 6 --cols 4 --rows 2 --names ring,burst,tracer,heal,flame,fireball,laser,orb --out $O/vfx_b --target-height 220 --scale-ref max --anchor center
python3 $S $A/vfx_alpha.png --cols 4 --rows 2 --names dust,scorch,rocks,splinters,shards,smoke_grey,smoke_black,casing --out $O/vfx_c --target-height 180 --scale-ref max --anchor center
python3 $S $A/props2.png --cols 4 --rows 2 --names fuel_tank,nest_base,mg_gun,sign,ammo_box,burning_drum,barriers,medal --out $O/props2 --target-height 170 --scale-ref fuel_tank --anchor bottom
python3 $S $A/decor_canyon.png --cols 4 --rows 2 --names hoodoo,cactus,boxcar,pier,minecart,water_tower,boulders,skull --out $O/decor_canyon --target-height 520 --scale-ref hoodoo --anchor bottom
python3 $S $A/decor_fortress.png --cols 4 --rows 2 --names watchtower,silo,banner,radar,pipes,crates,jeep,hedgehog --out $O/decor_fortress --target-height 560 --scale-ref watchtower --anchor bottom
python3 tools/art/process_v2_env.py "$A"
python3 tools/art/build_sprite_db.py
