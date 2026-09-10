#!/usr/bin/env python3
"""Merge profile.base.json with an .itermcolors theme for Dynamic Profiles."""

from __future__ import annotations

import json
import plistlib
import sys
from pathlib import Path
from typing import Any


def color_entry(plist_color: dict[str, Any]) -> dict[str, Any]:
    entry = {
        "Red Component": plist_color["Red Component"],
        "Green Component": plist_color["Green Component"],
        "Blue Component": plist_color["Blue Component"],
    }
    if "Alpha Component" in plist_color:
        entry["Alpha Component"] = plist_color["Alpha Component"]
    if "Color Space" in plist_color:
        entry["Color Space"] = plist_color["Color Space"]
    return entry


def build_profile(base_path: Path, theme_path: Path) -> dict[str, Any]:
    profile_data = json.loads(base_path.read_text(encoding="utf-8"))
    theme = plistlib.loads(theme_path.read_bytes())

    if not profile_data.get("Profiles"):
        raise SystemExit("profile.base.json must contain a Profiles array")

    profile = profile_data["Profiles"][0]
    for key, value in theme.items():
        if isinstance(value, dict) and "Red Component" in value:
            profile[key] = color_entry(value)

    return profile_data


def main() -> None:
    if len(sys.argv) != 4:
        raise SystemExit(f"usage: {sys.argv[0]} <profile.base.json> <theme.itermcolors> <output.json>")

    base_path = Path(sys.argv[1])
    theme_path = Path(sys.argv[2])
    output_path = Path(sys.argv[3])

    output_path.write_text(
        json.dumps(build_profile(base_path, theme_path), indent=2) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
