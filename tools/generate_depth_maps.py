#!/usr/bin/env python3
"""Generate depth maps for the planet hub backgrounds.

The planet screen fakes a 3D camera by displacing the painted background with
a depth map (see shaders/depth_parallax.gdshader). This script derives those
maps from the illustrations with Depth Anything V2.

Output: assets/sprites/scenes/bg_<planet>_depth.png -- 8-bit grayscale at half
resolution, white = near, black = far, lightly blurred so the displacement
bends instead of tearing at object edges.

Setup (once, outside the repo):
    python3 -m venv depthenv
    depthenv/bin/pip install torch transformers pillow
Run:
    depthenv/bin/python tools/generate_depth_maps.py [planet ...]
"""

import sys
from pathlib import Path

from PIL import Image, ImageFilter, ImageOps
from transformers import pipeline

MODEL = "depth-anything/Depth-Anything-V2-Base-hf"
SCENES_DIR = Path(__file__).resolve().parent.parent / "assets" / "sprites" / "scenes"
PLANETS = [
    "starport_alpha",
    "nexus_prime",
    "forge_world",
    "green_reach",
    "iron_belt",
    "dust_haven",
    "nova_station",
    "crimson_base",
]
OUTPUT_SCALE = 0.5
BLUR_RADIUS = 3


def generate(estimator, planet: str) -> None:
    src = SCENES_DIR / f"bg_{planet}.png"
    dst = SCENES_DIR / f"bg_{planet}_depth.png"
    image = Image.open(src).convert("RGB")
    # The pipeline returns relative inverse depth, already resized to the
    # input: bright = close to the camera, which is what the shader expects.
    depth = estimator(image)["depth"].convert("L")
    depth = ImageOps.autocontrast(depth, cutoff=1)
    size = (round(image.width * OUTPUT_SCALE), round(image.height * OUTPUT_SCALE))
    depth = depth.resize(size, Image.LANCZOS).filter(ImageFilter.GaussianBlur(BLUR_RADIUS))
    depth.save(dst, optimize=True)
    print(f"{dst.name}: {size[0]}x{size[1]}")


def main() -> None:
    planets = sys.argv[1:] or PLANETS
    estimator = pipeline("depth-estimation", model=MODEL)
    for planet in planets:
        generate(estimator, planet)


if __name__ == "__main__":
    main()
