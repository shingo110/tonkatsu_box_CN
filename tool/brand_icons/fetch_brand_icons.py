"""Fetch the real brand mark for each domestic source into `assets/images`.

Six sources came into the CN fork without artwork, so their badges fell back to
a lettered monogram while every other source showed its own logo. Each mark
here comes from the vendor's own distribution:

* the App Store catalogue entry for the vendor's own app, or
* the vendor's own web icon — used for NeoDB, whose iOS listing belongs to a
  third-party client rather than to the site itself.

Every result is normalised to the shape the existing assets use: a 256x256
RGBA PNG called `icon_<slug>_color.png`, which `DataSourceUi.iconAsset` points
at directly. Re-running is safe and rewrites the same bytes.

Usage:
    <venv>/python tool/brand_icons/fetch_brand_icons.py [--check]

`--check` reports what each source would resolve to without writing anything.
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parents[2]
ASSET_DIR = REPO / "assets" / "images"

SIZE = 256

# Direct egress: a sandbox proxy answers some of these hosts with empty bodies.
CLEAN_ENV = {
    key: value
    for key, value in os.environ.items()
    if key.lower() not in {"http_proxy", "https_proxy", "all_proxy", "no_proxy"}
}
CLEAN_ENV["NO_PROXY"] = "127.0.0.1,localhost,::1"

OPENER = urllib.request.build_opener(urllib.request.ProxyHandler({}))

UA = "TonkatsuBox-CN/tool (+https://github.com/shingo110/tonkatsu_box_CN)"


@dataclass(frozen=True)
class Source:
    """One brand mark, and where the vendor publishes it."""

    slug: str
    label: str
    bundle_id: str | None = None
    url: str | None = None

    @property
    def asset_name(self) -> str:
        return f"icon_{self.slug}_color.png"


SOURCES: tuple[Source, ...] = (
    Source("taptap", "TapTap", bundle_id="com.easyplay.taptap.now"),
    Source("bangumi", "Bangumi", bundle_id="tv.bgm.Bangumi"),
    # No first-party iOS app: the only listing is a third-party client, so the
    # mark comes from NeoDB's own site.
    Source("neodb", "NeoDB", url="https://neodb.social/s/img/icon.png"),
    Source("weread", "WeRead", bundle_id="com.tencent.weread"),
    Source("douban", "Douban", bundle_id="com.douban.frodo"),
    Source("ximalaya", "Ximalaya", bundle_id="com.gemd.iting"),
)


def fetch(url: str) -> tuple[int, bytes]:
    request = urllib.request.Request(url, headers={"User-Agent": UA})
    try:
        with OPENER.open(request, timeout=30) as response:
            return response.status, response.read()
    except urllib.error.HTTPError as error:
        return error.code, error.read()
    except OSError as error:
        return -1, str(error).encode()


def app_store_icon(bundle_id: str) -> str:
    """The 512px artwork URL for [bundle_id], or raise if the listing is gone.

    The bundle id is checked against the response: a renamed or delisted app
    must fail loudly rather than quietly contribute a stranger's artwork.
    """
    query = urllib.parse.urlencode({"bundleId": bundle_id, "country": "cn"})
    status, body = fetch(f"https://itunes.apple.com/lookup?{query}")
    if status != 200:
        raise RuntimeError(f"lookup {bundle_id} -> {status}")
    payload = json.loads(body)
    results = payload.get("results") or []
    for row in results:
        if row.get("bundleId") != bundle_id:
            continue
        artwork = row.get("artworkUrl512") or row.get("artworkUrl100")
        if artwork:
            return str(artwork)
    raise RuntimeError(f"no artwork for {bundle_id}")


def resolve(source: Source) -> tuple[str, bytes]:
    """The bytes for [source], fetched from whichever channel it declares."""
    if source.bundle_id:
        status, body = fetch(app_store_icon(source.bundle_id))
    elif source.url:
        status, body = fetch(source.url)
    else:
        raise RuntimeError(f"{source.slug} declares no source")
    if status != 200:
        raise RuntimeError(f"{source.slug} icon -> {status}")
    return status, body


def normalise(raw: bytes) -> Image.Image:
    """A square, [SIZE]-wide RGBA image cut from whatever the vendor served."""
    image = Image.open(io.BytesIO(raw)).convert("RGBA")
    width, height = image.size
    if width != height:
        side = min(width, height)
        left = (width - side) // 2
        top = (height - side) // 2
        image = image.crop((left, top, left + side, top + side))
    return image.resize((SIZE, SIZE), Image.LANCZOS)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="report the resolved artwork without writing any file",
    )
    args = parser.parse_args()

    failures: list[str] = []
    for source in SOURCES:
        try:
            _, raw = resolve(source)
            original = Image.open(io.BytesIO(raw))
            icon = normalise(raw)
        except Exception as error:  # noqa: BLE001
            failures.append(source.slug)
            print(f"[FAIL] {source.label:<9} {error}")
            continue

        if args.check:
            print(
                f"[ OK ] {source.label:<9} {original.size[0]}x{original.size[1]}"
                f" -> {SIZE}x{SIZE}"
                f"  from {source.bundle_id or source.url}"
            )
            continue

        target = ASSET_DIR / source.asset_name
        icon.save(target, "PNG", optimize=True)
        digest = hashlib.sha256(target.read_bytes()).hexdigest()[:12]
        print(
            f"[ OK ] {source.label:<9} {original.size[0]}x{original.size[1]}"
            f" -> {target.stat().st_size:>6}B  {source.asset_name}  {digest}"
        )

    if failures:
        print("\nfailed: " + ", ".join(failures), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
