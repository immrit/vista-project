#!/usr/bin/env python3
"""
Synchronize Telegram emoji assets + unicode mapping from official Telegram Android repo.

Outputs:
  - assets/emoji/telegram/** (copied from upstream assets/emoji)
  - lib/features/emoji/data/telegram_emoji_map.json
  - tool/emoji/telegram_emoji_manifest.json
"""

from __future__ import annotations

import argparse
import codecs
import datetime as dt
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.request
import zipfile
from pathlib import Path


REPO = "DrKLO/Telegram"
DEFAULT_REF = "master"
EMOJI_DATA_PATH = "TMessagesProj/src/main/java/org/telegram/messenger/EmojiData.java"
EMOJI_ASSETS_PREFIX = "TMessagesProj/src/main/assets/emoji/"


def http_get(url: str) -> bytes:
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": "vista-emoji-sync/1.0",
            "Accept": "application/vnd.github+json",
        },
    )
    with urllib.request.urlopen(req, timeout=120) as resp:
        return resp.read()


def resolve_commit_sha(ref: str) -> str:
    if re.fullmatch(r"[0-9a-fA-F]{40}", ref):
        return ref.lower()
    data = json.loads(http_get(f"https://api.github.com/repos/{REPO}/commits/{ref}"))
    return data["sha"]


def download_repo_zip(sha: str) -> bytes:
    return http_get(f"https://codeload.github.com/{REPO}/zip/{sha}")


def decode_java_string(value: str) -> str:
    if "\\" not in value:
        return value
    decoded = codecs.decode(value, "unicode_escape")
    return decoded.encode("utf-16", "surrogatepass").decode("utf-16")


def parse_emoji_data_java(java_source: str) -> list[list[str]]:
    marker = "public static final String[][] data = {"
    start = java_source.find(marker)
    if start < 0:
        raise RuntimeError("Could not locate EmojiData.data in EmojiData.java")

    i = start + len(marker)
    depth = 1
    page_index = -1
    pages: list[list[str]] = []

    in_string = False
    escaped = False
    current = []

    while i < len(java_source) and depth > 0:
        ch = java_source[i]
        if in_string:
            if escaped:
                current.append(ch)
                escaped = False
            elif ch == "\\":
                current.append(ch)
                escaped = True
            elif ch == '"':
                in_string = False
                if depth >= 2 and page_index >= 0:
                    pages[page_index].append(decode_java_string("".join(current)))
                current = []
            else:
                current.append(ch)
            i += 1
            continue

        if ch == '"':
            in_string = True
            current = []
            i += 1
            continue
        if ch == "{":
            depth += 1
            if depth == 2:
                page_index += 1
                pages.append([])
            i += 1
            continue
        if ch == "}":
            depth -= 1
            i += 1
            continue
        i += 1

    if not pages:
        raise RuntimeError("No emoji pages parsed from EmojiData.java")
    return pages


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=False),
        encoding="utf-8",
    )


def apply_alpha_masks(repo_root: Path) -> None:
    script = repo_root / "tool" / "emoji" / "apply_telegram_alpha_masks.py"
    if not script.exists():
        return

    cmd = [sys.executable, str(script)]
    try:
        subprocess.run(cmd, cwd=repo_root, check=True)
    except subprocess.CalledProcessError as exc:
        raise RuntimeError(
            f"Alpha-mask composition failed with exit code {exc.returncode}"
        ) from exc


def sync_assets_and_mapping(repo_root: Path, sha: str) -> None:
    assets_out = repo_root / "assets" / "emoji" / "telegram"
    map_out = repo_root / "lib" / "features" / "emoji" / "data" / "telegram_emoji_map.json"
    manifest_out = repo_root / "tool" / "emoji" / "telegram_emoji_manifest.json"

    zip_bytes = download_repo_zip(sha)
    zf = zipfile.ZipFile(io.BytesIO(zip_bytes))
    top_dir = zf.namelist()[0].split("/", 1)[0]

    emoji_data_name = f"{top_dir}/{EMOJI_DATA_PATH}"
    if emoji_data_name not in zf.namelist():
        raise RuntimeError("EmojiData.java not found in downloaded archive")

    java_source = zf.read(emoji_data_name).decode("utf-8")
    pages = parse_emoji_data_java(java_source)

    if assets_out.exists():
        shutil.rmtree(assets_out)
    assets_out.mkdir(parents=True, exist_ok=True)

    copied_files = 0
    prefix = f"{top_dir}/{EMOJI_ASSETS_PREFIX}"
    for name in zf.namelist():
        if not name.startswith(prefix) or name.endswith("/"):
            continue
        relative = name[len(prefix) :]
        target = assets_out / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        with zf.open(name) as src, target.open("wb") as dst:
            shutil.copyfileobj(src, dst)
        copied_files += 1

    apply_alpha_masks(repo_root)

    mapping: dict[str, str] = {}
    for page, emojis in enumerate(pages):
        for idx, emoji_text in enumerate(emojis):
            mapping[emoji_text] = f"assets/emoji/telegram/{page}_{idx}.png"

    generated_at = dt.datetime.now(dt.timezone.utc).isoformat()
    map_payload = {
        "generated_by": "tool/emoji/sync_telegram_emoji.py",
        "source_repo": f"https://github.com/{REPO}",
        "commit_sha": sha,
        "generated_at": generated_at,
        "asset_count": copied_files,
        "map": mapping,
    }
    write_json(map_out, map_payload)

    manifest_payload = {
        "source_repo": f"https://github.com/{REPO}",
        "commit_sha": sha,
        "asset_count": copied_files,
        "emoji_pages": len(pages),
        "emoji_total": sum(len(p) for p in pages),
        "generated_at": generated_at,
        "assets_dir": str(assets_out.as_posix()),
        "map_file": str(map_out.as_posix()),
    }
    write_json(manifest_out, manifest_payload)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--ref",
        default=DEFAULT_REF,
        help="Git ref or full commit sha from DrKLO/Telegram (default: master)",
    )
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parents[2]
    sha = resolve_commit_sha(args.ref)
    sync_assets_and_mapping(repo_root, sha)
    print(f"Telegram emoji sync complete. commit={sha}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
