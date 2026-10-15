#!/usr/bin/env python3
"""Builds cmd/triwheel/assets/changelog.json (the launcher's "What's new"): each version's own notes,
newest first, from the release notes in tools/changelog/*.md (one file per version, named by it).

    python3 tools/changelog.py
"""
import json, os, re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tools", "changelog")


def key(v):
    main, _, pre = v.partition("-")
    nums = [int(x) for x in main.split(".")]
    if not pre:
        return (nums, 1, 0)
    return (nums, 0, int(pre.split(".")[-1]))


def main():
    out = []
    for f in os.listdir(SRC):
        if not f.endswith(".md"):
            continue
        v = f[:-3]
        text = open(os.path.join(SRC, f), encoding="utf-8").read()
        date, _, body = text.partition("\n")
        out.append({"version": v, "date": date.strip(), "notes": body.strip()})
    out.sort(key=lambda e: key(e["version"]), reverse=True)
    p = os.path.join(ROOT, "cmd", "triwheel", "assets", "changelog.json")
    json.dump(out, open(p, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(f"{len(out)} versions -> {p}")


if __name__ == "__main__":
    main()
