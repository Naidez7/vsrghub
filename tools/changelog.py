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
    # tools/changelog/history/<shown>.md: a version as the page shows it, standing for several
    # versions that were published (its second line, "covers: a b c"); those are left out, and the
    # launcher marks the shown one as "yours" when one of them is running
    out, covered = [], set()
    hist = os.path.join(SRC, "history")
    for f in sorted(os.listdir(hist)) if os.path.isdir(hist) else []:
        if not f.endswith(".md"):
            continue
        lines = open(os.path.join(hist, f), encoding="utf-8").read().split("\n")
        covers = lines[1].removeprefix("covers:").split()
        covered.update(covers)
        out.append({"version": f[:-3], "date": lines[0].strip(), "covers": covers,
                    "notes": "\n".join(lines[2:]).strip()})
    for f in os.listdir(SRC):
        if not f.endswith(".md"):
            continue
        v = f[:-3]
        if v in covered:
            continue
        text = open(os.path.join(SRC, f), encoding="utf-8").read()
        date, _, body = text.partition("\n")
        out.append({"version": v, "date": date.strip(), "notes": body.strip()})
    out.sort(key=lambda e: key(e["version"]), reverse=True)
    p = os.path.join(ROOT, "cmd", "triwheel", "assets", "changelog.json")
    json.dump(out, open(p, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(f"{len(out)} versions -> {p}")


if __name__ == "__main__":
    main()
