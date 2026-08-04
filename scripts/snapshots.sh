#!/usr/bin/env bash
# Renders Ladder's UI to PNGs under .snapshots/ so a change can be looked at.
#
#   scripts/snapshots.sh views                 headless component renders (fast, no window)
#   scripts/snapshots.sh app                   drives the real app and photographs it
#   scripts/snapshots.sh app <section…>        just those sections of the tour
#   scripts/snapshots.sh                       both
#
# Sections: first-run seeded pipeline stage-sheet journey tailor tailor-failure
#           cv-import-failure tag-failure job-import settings
set -euo pipefail

cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

mode="${1:-all}"
if [ $# -gt 0 ]; then shift; fi
common=(-project Ladder.xcodeproj -destination 'platform=macOS' -quiet)

render_views() {
  echo "→ rendering components to .snapshots/"
  TEST_RUNNER_LADDER_SNAPSHOTS=1 xcodebuild "${common[@]}" \
    -scheme Ladder -only-testing:LadderTests/SnapshotGallery test
}

tour_test() {
  case "$1" in
    first-run)   echo testTourTheApp ;;
    seeded)      echo testTourTheSeededApp ;;
    pipeline)    echo testTourPipelineSection ;;
    stage-sheet) echo testTourStageSheetSection ;;
    journey)     echo testTourJourneySection ;;
    tailor)      echo testTourTailorFlowSection ;;
    tailor-failure) echo testTourTailorFailureSection ;;
    cv-import-failure) echo testTourCVImportFailureSection ;;
    tag-failure) echo testTourTagSuggestionFailureSection ;;
    job-import)  echo testTourJobImportSection ;;
    settings)    echo testTourSettingsSection ;;
    *) return 1 ;;
  esac
}

render_app() {
  local sections=("$@")
  if [ ${#sections[@]} -eq 0 ]; then
    # The failure sections sit outside the seeded walk — each launches its own
    # stores — so the full sweep has to name them.
    sections=(first-run seeded tailor-failure cv-import-failure tag-failure)
    echo "→ touring the running app into .snapshots/ui/"
  else
    echo "→ touring ${sections[*]} into .snapshots/ui/"
  fi
  local only=() section method
  for section in "${sections[@]}"; do
    if ! method=$(tour_test "$section"); then
      echo "unknown tour section: $section" >&2
      echo "sections: first-run seeded pipeline stage-sheet journey tailor tailor-failure cv-import-failure tag-failure job-import settings" >&2
      exit 2
    fi
    only+=("-only-testing:LadderUITests/ScreenTour/$method")
  done
  local bundle=.snapshots/tour.xcresult
  rm -rf "$bundle" .snapshots/ui
  xcodebuild "${common[@]}" -scheme LadderUI "${only[@]}" -resultBundlePath "$bundle" test
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
  app) render_app "$@" ;;
  all)
    render_views
    render_app
    ;;
  *)
    echo "usage: $0 [views|app [section…]]" >&2
    exit 2
    ;;
esac

echo
find .snapshots -name '*.png' | sort
