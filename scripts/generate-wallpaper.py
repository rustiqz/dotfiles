#!/usr/bin/env python3
"""Generate wallpapers/.local/share/wallpapers/tokyonight-mountains.png.

TokyoNight-palette mountain silhouette, stars, and moon — the classic
motif for this theme. Kept as a source script rather than just committing
the PNG so the wallpaper is editable (tweak a color/seed and re-run)
instead of being a mystery binary blob.

Deterministic (fixed random seeds) so re-running produces byte-identical
output — this is "generated," not "randomized on every run."

Requires: rsvg-convert (librsvg — already a system dependency of GTK,
not separately tracked in packages/pacman.txt for that reason).

Usage: scripts/generate-wallpaper.py
"""

import random
import subprocess
import sys
from pathlib import Path

W, H = 1920, 1080

# Same hex values used throughout this repo (kitty/tokyonight.conf,
# waybar/style.css, rofi/config.rasi).
BG_TOP = "#16161e"
BG_BOTTOM = "#1a1b26"
STAR = "#c0caf5"
MOON = "#e0af68"
MOON_GLOW = "#e0af6833"
LAYER_FAR = "#1f2335"
LAYER_MID = "#292e42"
LAYER_NEAR = "#16161e"
ACCENT = "#7aa2f7"


def ridge(y_base: float, amplitude: float, n_points: int, seed_offset: int) -> list[tuple[float, float]]:
    rnd = random.Random(42 + seed_offset)
    step = W / (n_points - 1)
    return [(i * step, y_base + rnd.uniform(-amplitude, amplitude)) for i in range(n_points)]


def ridge_path(pts: list[tuple[float, float]], bottom: float = H) -> str:
    d = f"M 0,{bottom} L {pts[0][0]:.1f},{pts[0][1]:.1f} "
    for x, y in pts[1:]:
        d += f"L {x:.1f},{y:.1f} "
    d += f"L {W},{bottom} Z"
    return d


def build_svg() -> str:
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}">']

    parts.append(f'''
<defs>
  <linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0%" stop-color="{BG_TOP}"/>
    <stop offset="100%" stop-color="{BG_BOTTOM}"/>
  </linearGradient>
  <radialGradient id="moonglow" cx="50%" cy="50%" r="50%">
    <stop offset="0%" stop-color="{MOON_GLOW}"/>
    <stop offset="100%" stop-color="{MOON_GLOW}" stop-opacity="0"/>
  </radialGradient>
  <radialGradient id="horizonglow" cx="50%" cy="100%" r="70%">
    <stop offset="0%" stop-color="{ACCENT}" stop-opacity="0.10"/>
    <stop offset="100%" stop-color="{ACCENT}" stop-opacity="0"/>
  </radialGradient>
</defs>
''')
    parts.append(f'<rect x="0" y="0" width="{W}" height="{H}" fill="url(#sky)"/>')

    # Subtle accent glow near the horizon — ties the palette's blue
    # accent into the wallpaper without it dominating.
    parts.append(f'<rect x="0" y="{H*0.4}" width="{W}" height="{H*0.6}" fill="url(#horizonglow)"/>')

    # Stars: fixed seed, reproducible rather than different every run.
    star_rnd = random.Random(7)
    for _ in range(160):
        x = star_rnd.uniform(0, W)
        y = star_rnd.uniform(0, H * 0.55)
        r = star_rnd.choice([1, 1, 1, 1.5, 2])
        opacity = star_rnd.uniform(0.3, 0.9)
        parts.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r}" fill="{STAR}" opacity="{opacity:.2f}"/>')

    # Moon, upper-right, with a soft glow behind it.
    mx, my, mr = W * 0.78, H * 0.22, 70
    parts.append(f'<circle cx="{mx}" cy="{my}" r="{mr*3}" fill="url(#moonglow)"/>')
    parts.append(f'<circle cx="{mx}" cy="{my}" r="{mr}" fill="{MOON}"/>')

    # Three mountain layers, back to front. Ridgelines come from a fixed
    # seed, not hand-authored points — silhouettes don't need precise
    # proportions to read correctly (unlike the notification theme's
    # pixel-art car/tyre attempts, which did, and didn't survive contact
    # with an actual render).
    far = ridge(H * 0.62, 45, 9, 1)
    mid = ridge(H * 0.72, 60, 8, 2)
    near = ridge(H * 0.85, 70, 7, 3)

    parts.append(f'<path d="{ridge_path(far)}" fill="{LAYER_FAR}"/>')
    parts.append(f'<path d="{ridge_path(mid)}" fill="{LAYER_MID}"/>')
    parts.append(f'<path d="{ridge_path(near)}" fill="{LAYER_NEAR}"/>')

    parts.append("</svg>")
    return "\n".join(parts)


def main() -> None:
    repo_root = Path(__file__).resolve().parent.parent
    out_png = repo_root / "wallpapers/.local/share/wallpapers/tokyonight-mountains.png"
    out_png.parent.mkdir(parents=True, exist_ok=True)

    svg_path = out_png.with_suffix(".svg.tmp")
    svg_path.write_text(build_svg())
    try:
        subprocess.run(
            ["rsvg-convert", "-w", str(W), "-h", str(H), "-o", str(out_png), str(svg_path)],
            check=True,
        )
    finally:
        svg_path.unlink(missing_ok=True)

    print(f"wrote {out_png}")


if __name__ == "__main__":
    if subprocess.run(["which", "rsvg-convert"], capture_output=True).returncode != 0:
        sys.exit("rsvg-convert not found (librsvg) — install it first")
    main()
