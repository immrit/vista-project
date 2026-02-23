#!/usr/bin/env python3
"""
Compose Telegram emoji alpha masks into base emoji PNG files.

Input:
  - assets/emoji/telegram/metadata.bin
  - assets/emoji/telegram/{page}_{index}.png
  - assets/emoji/telegram/masks/{mask_id}.png

Output:
  - Overwrites mapped {page}_{index}.png with transparent-alpha composed image.
"""

from __future__ import annotations

import argparse
import struct
import sys
from pathlib import Path

from PIL import Image, ImageChops


EMOJI_INDEX_PAGE_STRIDE = 4096


def parse_metadata(path: Path) -> dict[int, int]:
    data = path.read_bytes()
    if len(data) % 4 != 0:
        raise RuntimeError(
            f"Invalid metadata size: {len(data)} bytes (must be multiple of 4)"
        )

    mapping: dict[int, int] = {}
    for offset in range(0, len(data), 4):
        emoji_index, mask_id = struct.unpack_from("<HH", data, offset)
        mapping[emoji_index] = mask_id
    return mapping


def apply_masks(emoji_dir: Path, dry_run: bool = False, verbose: bool = False) -> None:
    metadata_file = emoji_dir / "metadata.bin"
    masks_dir = emoji_dir / "masks"

    if not metadata_file.exists():
        raise FileNotFoundError(f"Missing metadata file: {metadata_file}")
    if not masks_dir.exists():
        raise FileNotFoundError(f"Missing masks directory: {masks_dir}")

    mapping = parse_metadata(metadata_file)
    mask_cache: dict[int, Image.Image] = {}

    updated = 0
    missing = 0
    failed = 0

    for emoji_index, mask_id in mapping.items():
        page = emoji_index // EMOJI_INDEX_PAGE_STRIDE
        index = emoji_index % EMOJI_INDEX_PAGE_STRIDE

        base_path = emoji_dir / f"{page}_{index}.png"
        mask_path = masks_dir / f"{mask_id}.png"

        if not base_path.exists() or not mask_path.exists():
            missing += 1
            if verbose:
                print(f"missing: base={base_path.exists()} mask={mask_path.exists()} {base_path.name} mask={mask_id}")
            continue

        try:
            with Image.open(base_path) as base_src:
                base = base_src.convert("RGBA")

            if mask_id not in mask_cache:
                with Image.open(mask_path) as mask_src:
                    mask_cache[mask_id] = mask_src.convert("L")

            mask = mask_cache[mask_id]
            if base.size != mask.size:
                mask = mask.resize(base.size, Image.Resampling.BILINEAR)

            # Keep original transparency details and constrain with mask.
            # Replacing alpha outright can create opaque black circles/squares
            # for assets that already contain meaningful alpha information.
            original_alpha = base.getchannel("A")
            composed_alpha = ImageChops.multiply(original_alpha, mask)
            base.putalpha(composed_alpha)

            if not dry_run:
                base.save(base_path, format="PNG", optimize=True)
            updated += 1
        except Exception as exc:  # pragma: no cover - diagnostic path
            failed += 1
            if verbose:
                print(f"failed: {base_path.name} mask={mask_id} error={exc}")

    print(
        f"Telegram alpha mask compose complete. updated={updated} missing={missing} failed={failed} total={len(mapping)} dry_run={dry_run}"
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parents[2]
    emoji_dir = repo_root / "assets" / "emoji" / "telegram"

    apply_masks(emoji_dir, dry_run=args.dry_run, verbose=args.verbose)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
