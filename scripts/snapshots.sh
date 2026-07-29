#!/usr/bin/env bash
# Renders Ladder's UI to PNGs under .snapshots/ so a change can be looked at.
#
#   scripts/snapshots.sh views   headless component renders (fast, no window)
#   scripts/snapshots.sh app     drives the real app and photographs it
#   scripts/snapshots.sh         both
set -euo pipefail

cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

mode="${1:-all}"
common=(-project Ladder.xcodeproj -destination 'platform=macOS' -quiet)

render_views() {
  echo "→ rendering components to .snapshots/"
  TEST_RUNNER_LADDER_SNAPSHOTS=1 xcodebuild "${common[@]}" \
    -scheme Ladder -only-testing:LadderTests/SnapshotGallery test
}

render_app() {
  echo "→ touring the running app into .snapshots/ui/"
  local bundle=.snapshots/tour.xcresult
  rm -rf "$bundle" .snapshots/ui
  xcodebuild "${common[@]}" -scheme LadderUI -resultBundlePath "$bundle" test
  xcrun xcresulttool export attachments \
    --path "$bundle" --output-path .snapshots/ui >/dev/null
  # Files come out named by uuid; the manifest carries the tour's name for
  # each, itself suffixed with "_<index>_<uuid>".
  python3 - .snapshots/ui <<'PY'
import json, pathlib, re, sys
out = pathlib.Path(sys.argv[1])
manifest = out / "manifest.json"
suffix = re.compile(r"_\d+_[0-9A-Fa-f-]{36}(?=\.[^.]+$)")
for entry in json.loads(manifest.read_text()):
    for a in entry.get("attachments", []):
        src = out / a["exportedFileName"]
        name = suffix.sub("", a.get("suggestedHumanReadableName", ""))
        if name and src.exists():
            src.rename(out / name)
manifest.unlink()
PY
}

case "$mode" in
  views) render_views ;;
  app) render_app ;;
  all)
    render_views
    render_app
    ;;
  *)
    echo "usage: $0 [views|app]" >&2
    exit 2
    ;;
esac

echo
find .snapshots -name '*.png' | sort
