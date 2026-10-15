#!/usr/bin/env python3
"""Regenerate config/tuning.json and matching en.json tuning labels for Side Scroller."""
import json
from pathlib import Path

S = [
    # key, default, min, max, step, category, apply, integrity, type, label, description
    ("move_speed", 330, 150, 520, 10, "PLAYER", "NEXT_RUN", "GAMEPLAY", "integer", "Run speed", "Top running speed in pixels per second."),
    ("acceleration", 3200, 800, 6000, 100, "PLAYER", "NEXT_RUN", "GAMEPLAY", "integer", "Acceleration", "How quickly the commando reaches full speed."),
    ("friction", 3600, 800, 6000, 100, "PLAYER", "NEXT_RUN", "GAMEPLAY", "integer", "Stopping grip", "How quickly the commando stops when you let go."),
    ("jump_power", 1000, 800, 1300, 10, "PLAYER", "NEXT_RUN", "GAMEPLAY", "integer", "Jump power", "Initial upward speed of a jump."),
    ("jump_release_speed", 420, 150, 800, 10, "PLAYER", "NEXT_RUN", "GAMEPLAY", "integer", "Short-hop cut", "Upward speed kept when you release jump early."),
    ("gravity", 2400, 1500, 3600, 50, "PLAYER", "NEXT_RUN", "GAMEPLAY", "integer", "Gravity", "Downward pull on the commando."),
    ("coyote_time", 0.1, 0, 0.3, 0.01, "PLAYER", "NEXT_RUN", "GAMEPLAY", "float", "Ledge grace", "Seconds you can still jump after leaving a ledge."),
    ("jump_buffer", 0.12, 0, 0.3, 0.01, "PLAYER", "NEXT_RUN", "GAMEPLAY", "float", "Jump buffer", "Seconds an early jump press is remembered."),
    ("grapple_range", 470, 260, 720, 10, "PLAYER", "NEXT_RUN", "GAMEPLAY", "integer", "Grapple range", "Maximum cable length of the grapple gauntlet."),
    ("grapple_speed", 2300, 1000, 3600, 50, "PLAYER", "NEXT_RUN", "GAMEPLAY", "integer", "Grapple speed", "Launch speed of the grapple claw."),
    ("throw_speed", 840, 400, 1400, 20, "PLAYER", "NEXT_RUN", "GAMEPLAY", "integer", "Throw strength", "Launch speed of thrown enemies and props."),
    ("fire_rate_scale", 1.0, 0.5, 2.0, 0.05, "PLAYER", "NEXT_RUN", "GAMEPLAY", "float", "Fire rate", "Multiplier on every weapon's rate of fire."),
    ("player_max_hp", 100, 50, 300, 10, "GAMEPLAY", "NEXT_RUN", "GAMEPLAY", "integer", "Max health", "Commando health per life."),
    ("lives", 3, 1, 9, 1, "GAMEPLAY", "NEXT_RUN", "GAMEPLAY", "integer", "Lives", "Lives before the mission fails."),
    ("enemy_damage_scale", 1.0, 0.25, 2.0, 0.05, "ENEMIES", "NEXT_RUN", "GAMEPLAY", "float", "Enemy damage", "Multiplier on all damage dealt to the commando."),
    ("enemy_fire_rate", 1.0, 0.5, 2.0, 0.05, "ENEMIES", "NEXT_RUN", "GAMEPLAY", "float", "Enemy aggression", "Multiplier on how often enemies attack."),
    ("enemy_health_scale", 1.0, 0.5, 2.5, 0.05, "ENEMIES", "NEXT_RUN", "GAMEPLAY", "float", "Enemy toughness", "Multiplier on enemy and boss health."),
    ("fury_duration", 8, 4, 14, 0.5, "PLAYER", "NEXT_RUN", "GAMEPLAY", "float", "FURY duration", "Seconds of golden overdrive per full FURY meter."),
    ("style_decay", 1.0, 0.3, 2.0, 0.05, "GAMEPLAY", "NEXT_RUN", "GAMEPLAY", "float", "Style decay", "How fast the STYLE rank drains when you stop fighting."),
    ("hitstop_scale", 1.0, 0, 2.0, 0.05, "ENVIRONMENT", "LIVE", "COSMETIC", "float", "Hit-stop", "Freeze-frame strength on heavy hits and kills."),
    ("post_fx", 1, 0, 1, 1, "ENVIRONMENT", "LIVE", "COSMETIC", "boolean", "Post effects", "Shockwave distortion, vignette and FURY grading."),
    ("particles_density", 1.0, 0.2, 1.0, 0.05, "ENVIRONMENT", "LIVE", "COSMETIC", "float", "Particle density", "Amount of sparks, smoke and debris."),
    ("camera_smoothing", 8, 2, 16, 0.5, "ENVIRONMENT", "LIVE", "COSMETIC", "float", "Camera smoothing", "How tightly the camera follows."),
    ("screen_shake", 1, 0, 1.5, 0.05, "ENVIRONMENT", "LIVE", "COSMETIC", "float", "Screen shake", "Strength of impact and explosion shake."),
    ("hud_opacity", 1, 0.5, 1, 0.05, "UI", "LIVE", "COSMETIC", "float", "HUD opacity", "Opacity of the combat HUD."),
    ("reduced_motion", 0, 0, 1, 1, "UI", "LIVE", "COSMETIC", "boolean", "Reduced motion", "Disables screen shake and flashes."),
    ("audio_master", 1, 0, 1, 0.05, "AUDIO", "LIVE", "COSMETIC", "float", "Master volume", "Overall volume."),
    ("audio_music", 1, 0, 1, 0.05, "AUDIO", "LIVE", "COSMETIC", "float", "Music volume", "Soundtrack volume."),
    ("audio_sfx", 1, 0, 1, 0.05, "AUDIO", "LIVE", "COSMETIC", "float", "Effects volume", "Weapons, explosions and impacts."),
    ("audio_ui", 1, 0, 1, 0.05, "AUDIO", "LIVE", "COSMETIC", "float", "Interface volume", "Menu sounds."),
]

settings = []
labels = {}
for key, d, lo, hi, step, cat, mode, integ, typ, label, desc in S:
    decimals = 0 if typ in ("integer", "boolean", "enum") else (2 if step < 0.1 else 1)
    settings.append({
        "key": key, "default": d, "min": lo, "max": hi, "step": step, "decimals": decimals,
        "id": f"{cat.lower()}.{key}", "category": cat, "type": typ, "apply_mode": mode,
        "integrity": integ, "label_key": f"tuning.setting.{key}", "description_key": f"tuning.description.{key}",
        "unit_key": "", "tags": [cat.lower(), key],
    })
    labels[f"tuning.setting.{key}"] = label
    labels[f"tuning.description.{key}"] = desc

Path("config/tuning.json").write_text(json.dumps({"version": 4, "settings": settings}, indent=2) + "\n")
en_path = Path("localization/en.json")
en = json.loads(en_path.read_text())
en = {k: v for k, v in en.items() if not (k.startswith("tuning.setting.") or k.startswith("tuning.description."))}
en.update(labels)
en_path.write_text(json.dumps(en, indent=2, ensure_ascii=False) + "\n")
print(len(settings), "settings")
