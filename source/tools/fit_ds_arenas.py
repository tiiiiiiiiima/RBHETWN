#!/usr/bin/env python3
"""Apply measured native floor fits to an arena manifest, preserving geometry.

Input is the actual GLTFDocument report from inspect_ds_arena_geometry.gd.
Battle scenes get a 20-unit central floor; throwing scenes get 36 units. This
only translates/scales the complete source stage and does not infer DS physics.
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
import struct


def contains(triangle: dict, point: tuple[float, float]) -> bool:
    vertices = [(triangle[key][0], triangle[key][2]) for key in "abc"]
    edges = [(vertices[(index + 1) % 3][0] - vertices[index][0]) * (point[1] - vertices[index][1]) - (vertices[(index + 1) % 3][1] - vertices[index][1]) * (point[0] - vertices[index][0]) for index in range(3)]
    return min(edges) >= -0.0001 or max(edges) <= 0.0001


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("geometry_report", type=Path)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--project", type=Path, required=True)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--throw-span", type=float, default=36.0)
    args = parser.parse_args()
    manifest = json.loads(args.manifest.read_text())
    geometry = json.loads(args.geometry_report.read_text())
    report = {}
    for group_id, group in manifest["groups"].items():
        primary = group["components"][0]
        stat = geometry[primary["path"].removeprefix("res://")]
        triangles = stat["flat_triangles"]
        center_heights = sorted({triangle["y"] for triangle in triangles if contains(triangle, (0.0, 0.0))}, key=abs)
        height = center_heights[0] if center_heights else stat["planes"][0]["y"]
        surface = [triangle for triangle in triangles if triangle["y"] == height]
        vertices = [triangle[key] for triangle in surface for key in "abc"]
        low = [min(vertex[axis] for vertex in vertices) for axis in range(3)]
        high = [max(vertex[axis] for vertex in vertices) for axis in range(3)]
        center = [(low[axis] + high[axis]) * 0.5 for axis in range(3)]
        short_span = min(high[0] - low[0], high[2] - low[2])
        if short_span <= 0.0:
            raise ValueError(f"No usable measured horizontal floor for {group_id}")
        target = args.throw_span if group["role"] == "throw" else 20.0
        if not math.isfinite(target) or target <= 0:
            raise ValueError("Floor span must be positive and finite")
        scale = target / short_span
        floor_y = sum(vertex[1] for vertex in vertices) / len(vertices)
        offset = [-center[0], -floor_y, -center[2]]
        world_low = [math.inf] * 3
        world_high = [-math.inf] * 3
        for component in group["components"]:
            stat = geometry[component["path"].removeprefix("res://")]
            bounds = stat["bounds"]
            component["geometry"] = {key: stat[key] for key in ["meshes", "triangles", "vertices", "textures", "bounds"]}
            raw = (args.project / component["path"].removeprefix("res://")).read_bytes()
            json_size = struct.unpack_from("<I", raw, 12)[0]
            doc = json.loads(raw[20:20 + json_size])
            component["exported_joint_animations"] = [animation.get("name", "") for animation in doc.get("animations", [])]
            component["embedded_texture_count"] = len(doc.get("images", []))
            if any("uri" in image for image in doc.get("images", [])):
                raise ValueError("Arena GLB requires an external image")
            for axis in range(3):
                world_low[axis] = min(world_low[axis], (bounds["min"][axis] + offset[axis]) * scale)
                world_high[axis] = max(world_high[axis], (bounds["max"][axis] + offset[axis]) * scale)
        samples = [(x, z) for x in [-5.2, -2.6, 0.0, 2.6, 5.2] for z in [-4.9, -2.45, 0.0, 2.45, 4.9]]
        covered = sum(any(contains(triangle, (x / scale + center[0], z / scale + center[2])) for triangle in surface) for x, z in samples)
        far_hint = max(150, math.ceil(max(math.sqrt(sum(value * value for value in point)) for point in [world_low, world_high]) + 50))
        group["pc_fit"] = {
            "uniform_scale": scale,
            "source_offset": offset,
            "source_floor_y": floor_y,
            "source_floor_bounds": {"min": low, "max": high},
            "source_floor_component": primary["id"],
            "target_short_floor_span": target,
            "world_floor_bounds": {
                "min": [(low[i] + offset[i]) * scale for i in range(3)],
                "max": [(high[i] + offset[i]) * scale for i in range(3)],
            },
            "world_bounds": {"min": world_low, "max": world_high},
            "camera_far_hint": far_hint,
            "adaptation": "Uniform scale and translation only; all component transforms, geometry and UV coordinates retained.",
            "sampled_flat_surface_coverage": {
                "samples": len(samples), "covered": covered,
                "pc_rectangle": [-5.2, -4.9, 5.2, 4.9],
                "purpose": "Verify visible flat field under the current roll rectangle; does not recreate original DS obstacle collision.",
            },
        }
        report[group_id] = {"scale": scale, "floor_y": floor_y, "coverage": covered, "far_hint": far_hint, "world_bounds": group["pc_fit"]["world_bounds"]}
    args.manifest.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    if args.report:
        args.report.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"fitted_groups": len(report), "flat_surface_samples": sum(group["coverage"] for group in report.values()), "manifest": str(args.manifest)}))


if __name__ == "__main__":
    main()
