# Side Scroller 2.0 (formerly Grapple Strike): Concept Proposal ("Operation: Dust Fang, Remastered")

## 1. What makes the genre fun: reference analysis

Classic and modern run-and-guns share a small set of mechanics. What sets the great ones apart is how generously every input is answered on screen and in the speakers.

| Game | Core loop | Signature mechanics | Juice and feel | What we take |
| --- | --- | --- | --- | --- |
| **Metal Slug** (SNK/Nazca, 1996+) | Advance, clear waves, rescue POWs, collect drop weapons, beat a set-piece boss | Touching enemies does not kill; generous air control; drop weapons (H, S, R) with an announcer; POWs hand out items; the Slug tank (3 hits, 8-way vulcan); close-range knife | Huge frame counts, expressive soldiers who goof off then panic and scream, exaggerated deaths, readable boss telegraphs (laser charges, tanks rear up) | Panic/alert personality, announcer weapon calls, telegraphed boss attacks, POW item gifts, a mounted-gun set piece |
| **Contra / Blazing Chrome** | Constant forward pressure, pattern learning, bosses | Spread gun, melee up close, mechs, regular checkpoints | Tight controls, strong retro score | Weapons must stay readable (no surprise playstyle swaps); checkpoints keep flow |
| **Broforce** | Blow everything up, rescue prisoners | Destructible terrain, chain reactions, enemies flail and run, lookouts raise alarms | "Triggering these is always a joy": cascading explosions, a screaming announcer that encourages you after deaths | **Chain-reaction explosives** with a CHAIN counter, panicking enemies, encouraging announcer lines |
| **Huntdown** | Cover-based run-and-gun with bounty bosses | Environmental kills (barrels, cars, falling objects); melee as a finisher | Slick pacing, B-movie one-liners, bosses with personalities | Environment as a weapon: explosive props and fuel tanks |
| **Cuphead** | Boss-rush with grading | Parry fills a super meter; grades at the end | Hand-drawn animation, dramatic knockouts | **FURY meter** filled by skillful, risky play; end-of-stage grading |

**Game-feel references.** From *The Art of Screenshake* (Vlambeer): bigger bullets, muzzle flash, impact effects, enemy knockback, permanence (casings, debris, scorch marks), camera lerp and look-ahead, screen shake, hit-stop, gun kick, camera kick, bigger explosions. From *Juice It or Lose It* (Jonasson and Purho): every action gets a cascade of response (tweens, squash and stretch, particles, sound), and the UI itself should bounce and react.

**Why these games are fun.** The player's intent (shoot, grab, throw) is answered immediately and generously, danger is readable, and mastery is visible through score, rank and meters. Escalation keeps the pace up: waves, set pieces, bosses.

## 2. Diagnosis of Side Scroller 1.0

| Area | Current state | Gap |
| --- | --- | --- |
| Loop | One continuous level; combo multiplier; arena locks | No stage identity or pacing beats, and no end-of-stage payoff |
| Mechanics | Strong grapple, carry and throw base | No meter-based "big move"; explosives don't chain; enemies have little personality |
| VFX | Procedural particles plus one explosion sheet | Muzzle flashes, impacts and explosions feel thin; no permanence decals, glow, shockwaves or post effects |
| HUD | Flat panels drawn in code | No portrait, no animated feedback, nothing flies to the HUD, no rank |
| Environment | One sunset backdrop for the whole mission | Every section looks the same |
| Audio | 2 BGM tracks, about 20 SFX | Needs a per-stage score, UI sounds, layered impacts and new stingers |
| Loading | One 11 MB PCK loads before the title | Everything downloads up front |

## 3. The concept: "Side Scroller 2.0"

**Pitch:** a three-stage arcade blitz where every grab, throw and explosion is answered with fireworks. It's built on three pillars:

1. **Weaponize everything.** Enemies, barrels, fuel tanks and crates are ammunition, and explosions chain.
2. **Style is score.** A live STYLE rank (D to S) and a FURY overdrive reward varied, aggressive play.
3. **Maximum feedback.** Layered VFX, a reactive HUD, screen-space post effects and a stage-specific soundtrack.

Concept art is in `docs/concept/`:

| Image | Shows |
| --- | --- |
| `concept_1_frontier_town.png` | Stage 1: HMG muzzle flash, barrel chain reaction, CHAIN x3, panic alert, full HUD |
| `concept_2_rustline_canyon.png` | Stage 2: grapple swing over the chasm in FURY mode, golden afterimages, drone kills |
| `concept_3_jackal_fortress_boss.png` | Stage 3: Rhino Crawler laser telegraph, MG-nest emplacement, ornate boss bar |
| `concept_4_hud_ui_kit.png` | HUD kit: portraits (normal/hurt/fury), bars, weapon panel, item slots, rank emblems, FURY gauge, buttons, banners |
| `concept_5_vfx_style_sheet.png` | VFX language: muzzle flashes, tracers, impacts, explosion stages, smoke, shockwave, grapple FX, UI juice |

### 3.1 Structure: three stages with identity

| Stage | Name | Setting | New beats | Music |
| --- | --- | --- | --- | --- |
| 1 | Dust Fang Town | Golden-hour adobe frontier town | Landing zone tutorial, town square ambush, barrel chain-reaction alley | "Dust Fang March": driving arcade rock |
| 2 | Rustline Canyon | Red-rock canyon, rusted rail trestle, chasms | Grapple swings, drone swarms, trestle fight, fuel tank traps | "Rustline Run": faster, synth-guitar |
| 3 | Jackal Fortress | Industrial fortress at dusk, searchlights, fires | Mortar gauntlet, **MG nest set piece**, Rhino Crawler boss | "Iron Jackal": heavy, then the boss theme "Rhino Crawler" |

Each stage has its own parallax sky and midground and its own music. A **STAGE CLEAR tally card** shows kills, rescues, best chain and a stage grade before a short "STAGE 2" title sting.

### 3.2 New mechanics

| Mechanic | Rules | Inspiration |
| --- | --- | --- |
| **STYLE rank** | A style gauge fills from kills, weighted by variety: grapple-throw kill ×2.0, knife ×1.6, explosion or chain ×1.5, air kill ×1.4, human-shield block ×1.2, plain shots ×1.0. Repeating the same method is worth less. Ranks D, C, B, A, S raise a score multiplier (×1 to ×3). The gauge decays over time and drops a rank when you're hit. | DMC-style ranks, Cuphead grading |
| **FURY overdrive** | The FURY meter fills from kills, rescues and rank-ups. At 100% press **F** (or R): 8 seconds of golden piercing shots at double fire rate, instant grapple reel, damage resistance and afterimages. Enemies slow slightly (time scale 0.85). Music gets a filter sweep and HUD flames. | Cuphead super meter, Metal Slug HMG power fantasy |
| **Chain reactions** | Explosive barrels and new **fuel tanks** ignite nearby explosives after a short delay. A CHAIN counter pops up with a bonus of chain × 250. Thrown enemies that hit barrels detonate them. | Broforce, Huntdown |
| **Enemy personality** | Lookouts shout "!" and alert the squad. Grunts **panic and flee** from lit grenades and burning barrels ("!!" bubble, sweat drops). Enemies launched by explosions ragdoll-spin. | Metal Slug soldiers, Broforce lookouts |
| **MG-nest set piece** | In Stage 3 the hero can man a sandbag heavy-MG emplacement (press L): 3-way aim, bottomless ammo, an overheat gauge, and a wave rush. | Metal Slug Slug/turret moments |
| **Boss telegraphs** | Horn laser: a red warning line and charge orb before the beam. Missiles show target reticles. Cracked armor sheds sparks and smoke as phases change. The final KO gets a slow-mo white flash and a long explosion cascade. | Metal Slug fairness through telegraphs |

### 3.3 VFX and juice specification

Everything below is pooled and batched in a single draw layer, with caps so the browser holds 60 fps.

| Event | Response layers |
| --- | --- |
| Firing | Weapon-specific muzzle-flash sprite with additive glow; gun kick and camera kick opposite the shot; shell casings that stay on the ground for a while; bullets drawn with glowing tracer streaks |
| Bullet impact | Spark-burst sprite on metal or armor, dust puff on ground, small hit-stop on kills, enemy knockback and white flash |
| Explosion | White flash frame, then a fireball animation, Kenney smoke puffs rolling up, a shockwave ring (screen distortion shader), debris chunks and embers, a ground scorch decal that lingers, a light flash on the screen overlay, trauma-based camera shake and a zoom punch for large blasts |
| Grapple | Glowing cyan cable with sparks along it, latch spark burst, speed lines during zip or reel, swing motion trail |
| Throw | Spin trail, impact shockwave, "BOWLED x2!" popup when a thrown body hits several enemies |
| FURY | Golden aura outline, afterimage trail, warm vignette and chromatic-aberration fringe, ember rain, golden bullets |
| Hurt | Red vignette pulse, chromatic aberration, HUD shake, portrait switches to hurt, heartbeat pulse at low HP |
| Wave clear / boss KO | Slow motion (0.3 s / 1.5 s), radial burst, big banner |
| Ambient | Dust motes in Stage 1, drifting sand in Stage 2, embers and searchlight sweeps in Stage 3 |

### 3.4 Reactive HUD and UI

The HUD uses generated art from the kit in `concept_4_hud_ui_kit.png`. All text stays live.

| Element | Interactive feedback |
| --- | --- |
| Portrait badge (normal / hurt / fury) | Flashes and shakes on hit; golden frame and flame particles in FURY |
| Segmented health bar | Trailing white "damage ghost" that drains after a delay; heal sparkle; red pulse below 30% |
| Weapon panel | Icon flip plus burst when you pick up a weapon; ammo digits pop and blink red when low |
| Score plate | Rolling counter, digit flare and particle spray on big gains |
| STYLE emblem D to S | Punch-scale, radial burst and sound on rank-up; cracks and falls on rank-down; gauge underneath |
| FURY gauge | Flame fill; when full it pulses and spits sparks and shows "F: FURY" |
| Item slots | Pickups fly from the world into the slot on a trail, then the slot bursts; the selected slot glows |
| Stage progress track | Marker moves with a spark; skull icon for the boss |
| Menus | Button hover gets a glow sweep and spark particles; press gets a burst and a thump; ember particles on title and pause |
| Banners | STAGE CLEAR and MISSION FAILED banner art with slam-in animation and dust |

### 3.5 Audio direction

| Track / set | Content |
| --- | --- |
| BGM (6 new) | Title theme, Stage 1 march, Stage 2 run, Stage 3 fortress, boss battle, victory fanfare, plus a game-over sting |
| SFX (about 35 new or remade) | Four weapon voices, rocket, grenade bounce, 3 explosion sizes, chain whoosh, grapple fire/latch/reel/zip, throw, body impact, shield block, knife, footstep and land, pickup, weapon get, FURY activate/loop end, rank up/down, UI hover/confirm/back/pause, alarm, mortar whistle, laser charge/fire, MG nest, POW thanks, stage clear stinger |
| Catalog SFX (CC0/free) | Metal impacts, punches, debris crashes, heavy thuds, reload clicks and explosions, layered with the generated SFX |

### 3.6 Staggered loading plan

| Phase | What loads | When |
| --- | --- | --- |
| **Boot pack (main PCK)** | Engine scripts, fonts, title art, HUD kit, UI SFX, title music, hero, Stage 1 enemies, Stage 1 backgrounds, core VFX | Before the title |
| **Stage 2 pack** | Canyon backgrounds, drone/brute sprites, Stage 2 music | Downloaded in the background right after the title is interactive |
| **Stage 3 pack** | Fortress backgrounds, mortar, boss, MG nest, Stage 3 and boss music, victory music | Background prefetch once Stage 2 is ready |

Segment packs are Godot resource packs hosted on project storage (`/manus-storage/…`) and mounted with `ProjectSettings.load_resource_pack`. Downloads stream in the background, and GPU/texture warm-up runs a bounded amount per frame. **Prefetch pauses** when frame time rises, the particle count passes a threshold, or more than 6 enemies are on screen, and it resumes when things calm down. If the player reaches a stage gate before its pack is ready, the gate shows a "RESUPPLYING…" progress state with Retry; it never enters with missing assets. Native and editor builds read assets straight from the project.

## 4. Implementation scope

The work is split into phases:

1. **Art and audio production:** stage backgrounds (2 new stages × 2 layers), HUD kit sprites, VFX sprite sheets, a fuel tank, the MG nest and a POW cheer frame; the loading background, favicon and OG card; 7 music tracks and about 35 SFX, plus catalog smoke and SFX.
2. **Systems:** a `style.gd` rank/FURY model, a chain-reaction explosive graph, panic AI, the MG nest, boss telegraphs, the stage manager with tally, and segment loading (`segment_loader.gd`).
3. **Juice:** a new `fx.gd` with sprite VFX, decals, a glow layer and a post-process shader (vignette, aberration, shockwave); camera trauma, kick and zoom punch; slow motion.
4. **HUD rewrite:** `hud.gd` using the kit art plus UI particles; animated title and menus.
5. **Verification:** smoke, progression and bot tests; native captures compared against the concepts; checkpoint.
