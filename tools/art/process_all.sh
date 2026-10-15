#!/usr/bin/env bash
# Rebuild base-game runtime sprites from the generated masters in ART_RAW.
set -euo pipefail
cd "$(dirname "$0")/../.."
S=tools/art/slice_sheet.py
A=${ART_RAW:?Set ART_RAW to the original base-game masters directory}
O=assets/template/game/sprites
mkdir -p "$O"
python3 $S $A/hero_poses.png --cols 4 --rows 3 --names idle,idle2,aim_up,crouch,jump,aim_down,throw,carry,grapple,slash,hurt,dead --out $O/hero --target-height 224 --scale-ref idle --anchor torso
python3 $S $A/hero_run.png --cols 4 --rows 2 --names run0,run1,run2,run3,run4,run5,run6,run7 --out $O/hero_run --target-height 216 --scale-ref median --anchor torso
python3 $S $A/grunt_sheet.png --cols 4 --rows 2 --names walk0,walk1,walk2,walk3,fire,grabbed,hurt,dead --out $O/grunt --target-height 216 --scale-ref walk0 --anchor torso
python3 $S $A/shield_sheet.png --cols 4 --rows 2 --names walk0,walk1,walk2,walk3,fire,stagger,grabbed,dead --out $O/shield --target-height 232 --scale-ref walk0 --anchor torso
python3 $S $A/brute_sheet.png --cols 4 --rows 2 --names walk0,walk1,walk2,walk3,windup,punch,stunned,dead --out $O/brute --target-height 330 --scale-ref walk0 --anchor torso
python3 $S $A/drone_sheet.png --cols 2 --rows 2 --names hover0,hover1,drop,wreck --out $O/drone --target-height 128 --scale-ref hover0 --anchor center
python3 $S $A/boss_hull.png --cols 1 --rows 1 --names hull --out $O/boss --target-height 400 --scale-ref hull --anchor center
python3 $S $A/boss_turret.png --cols 1 --rows 1 --names turret --out $O/boss_turret --target-height 220 --scale-ref turret --anchor center
python3 $S $A/mortar.png --cols 1 --rows 1 --names bunker --out $O/mortar --target-height 250 --scale-ref bunker --anchor bottom
python3 $S $A/props_sheet.png --cols 4 --rows 2 --names crate,barrel,anchor,flag,pow_tied,pow_free,sandbags,ammo_crate --out $O/props --target-height 128 --scale-ref crate --anchor bottom
python3 $S $A/items_sheet.png --cols 4 --rows 2 --names medkit,grenades,hmg,spread,rocket,shield,medal,gold --out $O/items --target-height 96 --scale-ref median --anchor center
python3 $S $A/explosion_sheet.png --cols 4 --rows 2 --names ex0,ex1,ex2,ex3,ex4,ex5,ex6,ex7 --out $O/explosion --target-height 256 --scale-ref max --anchor center
python3 $S $A/decor_sheet.png --cols 4 --rows 2 --names palm,jeep,wire,wall,tower,rubble,tent,agave --out $O/decor --target-height 560 --scale-ref palm --anchor bottom
python3 tools/art/process_backgrounds.py "$A"
python3 tools/art/build_sprite_db.py
