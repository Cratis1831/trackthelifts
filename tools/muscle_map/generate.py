#!/usr/bin/env python3
"""Generates the muscle anatomy silhouettes (front + back view) as SVG.

Every muscle is drawn once for the figure's right side (left half of each view)
and mirrored, so the figure stays perfectly symmetric. Muscles are grouped by the
same bodypart names used in ExerciseData.defaultBodyparts, so any group can be
highlighted.

Usage:
    python3 tools/muscle_map/generate.py            # regenerates the asset catalog SVGs
"""

from pathlib import Path

BASE_FILL = "#2C2C2E"       # body silhouette (shows through as definition lines)
MUSCLE_FILL = "#636366"     # neutral muscle
HIGHLIGHT_FILL = "#0A84FF"  # iOS system blue

CENTER_X = 100
BACK_OFFSET_X = 220
VIEWBOX = "0 0 420 412"

# --- Path helpers ---------------------------------------------------------
# A path is a start point followed by segments of absolute commands:
#   ("L", (x, y)) | ("Q", (cx, cy), (x, y)) | ("C", (c1x, c1y), (c2x, c2y), (x, y))


def _fmt(pt, dx=0, mirror=False):
    x, y = pt
    if mirror:
        x = 2 * CENTER_X - x
    return f"{x + dx:g} {y:g}"


def path_d(start, segs, dx=0, mirror=False):
    parts = [f"M{_fmt(start, dx, mirror)}"]
    for cmd, *pts in segs:
        parts.append(cmd + " ".join(_fmt(p, dx, mirror) for p in pts))
    return " ".join(parts) + " Z"


def symmetric_d(start, segs, dx=0):
    """Closes a left-half outline (from centre line to centre line) by mirroring it."""
    points = [start]
    for _, *pts in segs:
        points.append(pts[-1])
    reversed_segs = []
    for i in range(len(segs) - 1, -1, -1):
        cmd, *pts = segs[i]
        controls = list(reversed(pts[:-1]))
        reversed_segs.append((cmd, *controls, points[i]))

    def m(p):
        return (2 * CENTER_X - p[0], p[1])

    parts = [f"M{_fmt(start, dx)}"]
    for cmd, *pts in segs:
        parts.append(cmd + " ".join(_fmt(p, dx) for p in pts))
    for cmd, *pts in reversed_segs:
        parts.append(cmd + " ".join(_fmt(m(p), dx) for p in pts))
    return " ".join(parts) + " Z"


# --- Base silhouette (shared by front and back) -----------------------------

TORSO = ((100, 62), [
    ("L", (90, 63)),
    ("L", (90, 76)),
    ("C", (80, 82), (62, 81), (53, 87)),
    ("C", (44, 93), (43, 110), (47, 124)),
    ("L", (64, 130)),
    ("C", (66, 158), (70, 178), (69, 196)),
    ("C", (69, 205), (63, 209), (61, 216)),
    ("C", (60, 226), (80, 238), (100, 242)),
])

ARM = ((48, 116), [
    ("C", (41, 134), (41, 152), (44, 166)),
    ("C", (37, 184), (41, 210), (48, 227)),
    ("L", (59, 227)),
    ("C", (62, 205), (63, 182), (61, 166)),
    ("C", (63, 150), (65, 132), (64, 122)),
])

LEG = ((61, 212), [
    ("C", (57, 240), (59, 290), (69, 318)),
    ("C", (67, 342), (70, 372), (74, 393)),
    ("L", (87, 393)),
    ("C", (89, 370), (95, 342), (91, 318)),
    ("C", (95, 300), (99, 272), (99.5, 238)),
    ("L", (99.5, 212)),
])


def base_shapes(dx):
    out = [
        f'<ellipse cx="{CENTER_X + dx}" cy="38" rx="18" ry="23"/>',
        f'<path d="{symmetric_d(*TORSO, dx=dx)}"/>',
    ]
    for mirror in (False, True):
        out.append(f'<path d="{path_d(*ARM, dx=dx, mirror=mirror)}"/>')
        out.append(f'<path d="{path_d(*LEG, dx=dx, mirror=mirror)}"/>')
        hx = 53.5 if not mirror else 2 * CENTER_X - 53.5
        fx = 80.5 if not mirror else 2 * CENTER_X - 80.5
        out.append(f'<ellipse cx="{hx + dx:g}" cy="239" rx="6.5" ry="13"/>')
        out.append(f'<ellipse cx="{fx + dx:g}" cy="399" rx="8.5" ry="8"/>')
    return out


# --- Muscles ----------------------------------------------------------------
# (group, name, start, segments) — all drawn on the left half of the view.

FRONT_MUSCLES = [
    ("Shoulders", "trapezius-upper", (90, 66), [
        ("L", (90.5, 79)), ("L", (64, 85)), ("Q", (78, 77), (90, 66))]),
    ("Shoulders", "deltoid-front", (63, 86), [
        ("Q", (50, 86), (46.5, 100)), ("Q", (44.5, 114), (49.5, 124)),
        ("Q", (56, 110), (61.5, 102)), ("Q", (65, 94), (63, 86))]),
    ("Chest", "pectoralis", (98.5, 89), [
        ("L", (98.5, 129)), ("Q", (84, 136), (70, 128)),
        ("Q", (63, 118), (63.5, 104)), ("Q", (67, 92), (80, 88)),
        ("Q", (91, 86), (98.5, 89))]),
    ("Biceps", "biceps", (50.5, 127), [
        ("Q", (43.5, 142), (46, 157)), ("Q", (49, 166), (54.5, 165)),
        ("Q", (60.5, 157), (60.5, 142)), ("Q", (61, 120), (62, 107)),
        ("Q", (55, 115), (50.5, 127))]),
    ("Forearms", "forearm", (46, 168), [
        ("Q", (39, 182), (41, 197)), ("Q", (44, 214), (49.5, 224)),
        ("L", (57.5, 224)), ("Q", (60.5, 206), (60, 190)),
        ("Q", (60, 175), (57.5, 168)), ("Q", (52, 171), (46, 168))]),
    ("Abs", "rectus-abdominis-1", (86, 135), [
        ("L", (98.5, 133)), ("L", (98.5, 149)), ("L", (86, 150))]),
    ("Abs", "rectus-abdominis-2", (86, 153), [
        ("L", (98.5, 152)), ("L", (98.5, 168)), ("L", (86.5, 169))]),
    ("Abs", "rectus-abdominis-3", (86.5, 172), [
        ("L", (98.5, 171)), ("L", (98.5, 188)), ("L", (87, 189))]),
    ("Abs", "rectus-abdominis-4", (87, 192), [
        ("L", (98.5, 191)), ("L", (98.5, 228)), ("Q", (91, 224), (88, 212))]),
    ("Abs", "oblique", (83.5, 134), [
        ("L", (84.5, 190)), ("Q", (85, 208), (86, 216)),
        ("Q", (74, 208), (70, 196)), ("Q", (70, 172), (66.5, 134)),
        ("Q", (74, 136), (83.5, 134))]),
    ("Quadriceps", "vastus-lateralis", (65, 219), [
        ("Q", (70, 238), (70.5, 262)), ("Q", (72, 288), (77, 307)),
        ("Q", (70, 308), (67, 300)), ("Q", (60.5, 280), (60.5, 255)),
        ("Q", (61, 232), (65, 219))]),
    ("Quadriceps", "rectus-femoris", (69, 224), [
        ("Q", (79, 232), (83, 252)), ("Q", (86, 276), (81.5, 302)),
        ("L", (79, 304)), ("Q", (73, 282), (72.5, 258)),
        ("Q", (71.5, 236), (69, 224))]),
    ("Quadriceps", "vastus-medialis", (88, 277), [
        ("Q", (94, 290), (92, 304)), ("Q", (88.5, 312), (82, 310)),
        ("Q", (80.5, 300), (83.5, 290)), ("Q", (85, 282), (88, 277))]),
    ("Adductors", "adductors", (85, 240), [
        ("Q", (92, 241), (98.5, 244)), ("Q", (97, 262), (89.5, 280)),
        ("Q", (86.5, 268), (85, 252))]),
    ("Calves", "tibialis-anterior", (73, 328), [
        ("Q", (69.5, 346), (72, 366)), ("Q", (74, 380), (77, 389)),
        ("L", (80.5, 389)), ("Q", (80, 360), (81, 340)),
        ("Q", (80, 330), (78, 326))]),
    ("Calves", "gastrocnemius-medial", (83.5, 328), [
        ("Q", (91, 340), (90, 358)), ("Q", (88, 372), (84, 381)),
        ("Q", (82, 360), (82.5, 340))]),
]

BACK_MUSCLES = [
    ("Back", "trapezius", (99.5, 64), [
        ("L", (91, 66)), ("Q", (88, 78), (64, 85.5)),
        ("Q", (80, 96), (88, 116)), ("Q", (94, 134), (99.5, 151))]),
    ("Shoulders", "deltoid-rear", (63, 88), [
        ("Q", (50, 86), (46.5, 100)), ("Q", (44.5, 114), (49.5, 124)),
        ("Q", (57, 111), (65.5, 100))]),
    ("Back", "infraspinatus", (68, 96), [
        ("Q", (80, 100), (86, 118)), ("Q", (78, 128), (68.5, 126)),
        ("Q", (64.5, 112), (68, 96))]),
    ("Back", "latissimus-dorsi", (66, 129), [
        ("Q", (77, 133), (88, 124)), ("Q", (92.5, 140), (90.5, 160)),
        ("Q", (87, 180), (87, 203)), ("Q", (77, 204), (71, 196)),
        ("Q", (70, 165), (66, 129))]),
    ("Back", "erector-spinae", (93, 148), [
        ("Q", (98.5, 152), (98.5, 162)), ("L", (98.5, 210)),
        ("Q", (92, 212), (89.5, 205)), ("Q", (89.5, 180), (93, 148))]),
    ("Triceps", "triceps", (50.5, 127), [
        ("Q", (43.5, 142), (46, 157)), ("Q", (49, 166), (54.5, 165)),
        ("Q", (60.5, 157), (60.5, 142)), ("Q", (61, 120), (62, 107)),
        ("Q", (55, 115), (50.5, 127))]),
    ("Forearms", "forearm-extensors", (46, 168), [
        ("Q", (39, 182), (41, 197)), ("Q", (44, 214), (49.5, 224)),
        ("L", (57.5, 224)), ("Q", (60.5, 206), (60, 190)),
        ("Q", (60, 175), (57.5, 168)), ("Q", (52, 171), (46, 168))]),
    ("Glutes", "gluteus", (99, 214), [
        ("Q", (84, 209), (71, 212)), ("Q", (61, 220), (61.5, 237)),
        ("Q", (64, 255), (78, 258)), ("Q", (92, 259), (99, 251))]),
    ("Hamstrings", "biceps-femoris", (65, 261), [
        ("Q", (74, 264), (82, 263)), ("Q", (84.5, 286), (82, 310)),
        ("Q", (74, 311), (70, 300)), ("Q", (63, 282), (65, 261))]),
    ("Hamstrings", "semitendinosus", (85, 263), [
        ("Q", (93, 262), (97.5, 257)), ("Q", (97, 286), (90.5, 311)),
        ("Q", (86.5, 311), (85, 305)), ("Q", (86.5, 285), (85, 263))]),
    ("Calves", "gastrocnemius-lateral", (72, 326), [
        ("Q", (67.5, 340), (70, 356)), ("Q", (74, 367), (79.5, 364)),
        ("Q", (81.5, 345), (79.5, 326))]),
    ("Calves", "gastrocnemius-medial", (82.5, 326), [
        ("Q", (92, 334), (91, 352)), ("Q", (88.5, 366), (82.5, 366)),
        ("Q", (81, 345), (82.5, 326))]),
    ("Calves", "soleus", (72.5, 364), [
        ("Q", (76, 371), (81, 370)), ("Q", (86, 370), (89.5, 360)),
        ("Q", (88, 378), (85, 389)), ("L", (77, 389)),
        ("Q", (74, 377), (72.5, 364))]),
]


def muscle_paths(muscles, dx, highlighted):
    out = []
    for group, name, start, segs in muscles:
        fill = HIGHLIGHT_FILL if group in highlighted else MUSCLE_FILL
        slug = group.lower().replace(" ", "-")
        for side, mirror in (("right", False), ("left", True)):
            out.append(
                f'<path id="{slug}-{name}-{side}" fill="{fill}" '
                f'd="{path_d(start, segs, dx=dx, mirror=mirror)}"/>'
            )
    return out


def render(highlighted=()):
    highlighted = set(highlighted)
    lines = [
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{VIEWBOX}" '
        f'width="420" height="412">',
        f'<g id="silhouette" fill="{BASE_FILL}">',
        *base_shapes(0),
        *base_shapes(BACK_OFFSET_X),
        "</g>",
        '<g id="front">',
        *muscle_paths(FRONT_MUSCLES, 0, highlighted),
        "</g>",
        '<g id="back">',
        *muscle_paths(BACK_MUSCLES, BACK_OFFSET_X, highlighted),
        "</g>",
        "</svg>",
    ]
    return "\n".join(lines) + "\n"


ASSETS = Path(__file__).resolve().parents[2] / "trackthelifts" / "Assets.xcassets"

IMAGESETS = {
    "MuscleAnatomy": (),
    "MuscleAnatomyQuadriceps": ("Quadriceps",),
}

CONTENTS_JSON = """{{
  "images" : [
    {{
      "filename" : "{name}.svg",
      "idiom" : "universal"
    }}
  ],
  "info" : {{
    "author" : "xcode",
    "version" : 1
  }},
  "properties" : {{
    "preserves-vector-representation" : true
  }}
}}
"""

if __name__ == "__main__":
    for name, highlighted in IMAGESETS.items():
        folder = ASSETS / f"{name}.imageset"
        folder.mkdir(exist_ok=True)
        (folder / f"{name}.svg").write_text(render(highlighted))
        (folder / "Contents.json").write_text(CONTENTS_JSON.format(name=name))
        print(f"wrote {folder}")
