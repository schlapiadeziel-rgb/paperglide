#!/usr/bin/env python3
"""Rewrite the [input] section of project.godot with Side Scroller's controls."""
import re
from pathlib import Path

K = {"Space": 32, "Escape": 4194305, "Tab": 4194306, "Enter": 4194309, "KPEnter": 4194310,
     "Left": 4194319, "Up": 4194320, "Right": 4194321, "Down": 4194322}
for c in "ABCDEFGHIJKLMNOPQRSTUVWXYZ":
    K[c] = ord(c)

ACTIONS = {
    "ui_accept": (["Enter", "KPEnter", "Space"], [0], []),
    "ui_cancel": (["Escape"], [1], []),
    "move_left": (["A", "Left"], [13], [(0, -1.0)]),
    "move_right": (["D", "Right"], [14], [(0, 1.0)]),
    "aim_up": (["W", "Up"], [11], [(1, -1.0)]),
    "aim_down": (["S", "Down"], [12], [(1, 1.0)]),
    "jump": (["Space", "Z"], [0], []),
    "shoot": (["J", "X"], [2], []),
    "grapple": (["K", "C"], [1], []),
    "grab": (["L", "V"], [3], []),
    "use_item": (["E"], [10], []),
    "switch_item": (["Q"], [9], []),
    "fury": (["F", "R"], [8], []),
    "pause": (["Escape", "P"], [6], []),
    "start": (["Enter", "KPEnter", "Space", "J"], [0], []),
    "skip_tutorial": (["Tab"], [4], []),
}


def key(code: int) -> str:
    return ('Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,'
            '"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,'
            f'"keycode":0,"physical_keycode":{code},"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)')


def joy(button: int) -> str:
    return ('Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":-1,'
            f'"button_index":{button},"pressure":0.0,"pressed":true,"script":null)')


def axis(a: int, v: float) -> str:
    return ('Object(InputEventJoypadMotion,"resource_local_to_scene":false,"resource_name":"","device":-1,'
            f'"axis":{a},"axis_value":{v},"script":null)')


lines = ["[input]", ""]
for name, (keys, buttons, axes) in ACTIONS.items():
    events = [key(K[k]) for k in keys] + [joy(b) for b in buttons] + [axis(a, v) for a, v in axes]
    lines.append(f"{name}={{")
    lines.append('"deadzone": 0.35,')
    lines.append('"events": [' + "\n, ".join(events) + "\n]")
    lines.append("}")
section = "\n".join(lines) + "\n\n"

p = Path("project.godot")
text = p.read_text()
text = re.sub(r"\[input\]\n.*?(?=\n\[layer_names\])", section.rstrip("\n") + "\n", text, flags=re.S)
p.write_text(text)
print("input map updated")
