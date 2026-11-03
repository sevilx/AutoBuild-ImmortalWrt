#!/usr/bin/env python3
"""根据 workflow 输入生成 GitHub Actions 的 matrix。

用法：
    python3 .github/plan.py --branch openwrt-24.10 --targets all
    python3 .github/plan.py --targets x86_64,armsr_armv8
"""
import argparse
import json
import pathlib
import sys


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--branch", default="openwrt-24.10")
    parser.add_argument("--targets", default="all")
    args = parser.parse_args()

    table = json.loads(
        pathlib.Path(".github/targets.json").read_text(encoding="utf-8")
    )

    raw = args.targets.replace("，", ",").replace(" ", ",")
    selected = [x for x in raw.split(",") if x]

    if not selected or selected == ["all"]:
        chosen = table
    else:
        known = {item["id"] for item in table}
        unknown = [x for x in selected if x not in known]
        if unknown:
            print(
                "未知的编译目标: %s（可选: %s）"
                % (", ".join(unknown), ", ".join(sorted(known))),
                file=sys.stderr,
            )
            return 2
        chosen = [item for item in table if item["id"] in selected]

    print(json.dumps({"include": chosen}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
