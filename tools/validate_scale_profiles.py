#!/usr/bin/env python3
"""Validate per-Pokemon scale profiles against the current Godot import report."""
import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / "godot_validation" / "godot_validation_report.json"
PROFILES = ROOT / "config" / "pokemon_scale_profiles.json"
OUTPUT = ROOT / "godot_validation" / "scale_profile_validation.json"
TOLERANCE_BOUNDS = 0.015
TOLERANCE_OFFSET = 0.015
TOLERANCE_SCALE_REL = 0.002


def close_vec(a, b, tol):
    return len(a) == len(b) and all(abs(float(x) - float(y)) <= tol for x, y in zip(a, b))


def main():
    report = json.loads(REPORT.read_text(encoding="utf-8"))
    profiles = json.loads(PROFILES.read_text(encoding="utf-8"))
    assets = {item["file"]: item for item in report["assets"]}
    results = []
    failures = []

    for filename, profile in profiles["pokemon"].items():
        asset = assets.get(filename)
        if not asset or not asset.get("loaded") or not asset.get("mesh_bounds"):
            failures.append(f"{filename}: GLB ausente, nao carregado ou sem malhas")
            continue

        bounds = asset["mesh_bounds"]
        mins = [[float(v) for v in b["world_min"]] for b in bounds]
        maxs = [[float(v) for v in b["world_max"]] for b in bounds]
        actual_min = [min(v[i] for v in mins) for i in range(3)]
        actual_max = [max(v[i] for v in maxs) for i in range(3)]
        actual_size = [actual_max[i] - actual_min[i] for i in range(3)]
        height = actual_size[1]
        expected_scale = float(profile["pokedex_height_m"]) / height
        center_x = (actual_min[0] + actual_max[0]) / 2.0
        center_z = (actual_min[2] + actual_max[2]) / 2.0
        expected_offset = [
            -center_x * expected_scale,
            -actual_min[1] * expected_scale,
            -center_z * expected_scale,
        ]

        checks = {
            "bounds_match": close_vec(profile["imported_aabb_min"], actual_min, TOLERANCE_BOUNDS)
                and close_vec(profile["imported_aabb_max"], actual_max, TOLERANCE_BOUNDS),
            "scale_match": abs(float(profile["uniform_scale"]) - expected_scale)
                <= max(1e-8, abs(expected_scale) * TOLERANCE_SCALE_REL),
            "offset_match": close_vec(profile["visual_offset"], expected_offset, TOLERANCE_OFFSET),
            "target_height_positive": float(profile["pokedex_height_m"]) > 0,
        }
        passed = all(checks.values())
        if not passed:
            failures.append(f"{filename}: {checks}")
        results.append({
            "file": filename,
            "name": profile["name"],
            "measured_height": round(height, 6),
            "pokedex_height_m": profile["pokedex_height_m"],
            "uniform_scale": profile["uniform_scale"],
            "expected_scale": round(expected_scale, 10),
            "visual_offset": profile["visual_offset"],
            "checks": checks,
            "passed": passed,
        })

    map_profile = profiles.get("map_preservation", {})
    map_asset = assets.get(map_profile.get("file", ""))
    map_unchanged = map_profile.get("modified") is False and map_asset is not None and map_asset.get("loaded") is True
    if not map_unchanged:
        failures.append("Mapa nao confirmado como preservado/carregado")

    output = {
        "profiles_checked": len(results),
        "profiles_passed": sum(1 for item in results if item["passed"]),
        "map_preserved_and_loaded": map_unchanged,
        "failures": failures,
        "results": results,
    }
    OUTPUT.write_text(json.dumps(output, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps({k: output[k] for k in ("profiles_checked", "profiles_passed", "map_preserved_and_loaded", "failures")}, indent=2, ensure_ascii=False))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
