#!/bin/bash
# Screenshot the running clock window: scripts/screenshot.sh out.png
# Uses the window id so only the panel is captured, at 2x on Retina displays.
set -euo pipefail
out="${1:-clock.png}"
id=$(swift - <<'SWIFT'
import CoreGraphics
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as! [[String: Any]]
for w in list where (w[kCGWindowOwnerName as String] as? String) == "Trading Clock" {
    if let b = w[kCGWindowBounds as String] as? [String: Double], (b["Height"] ?? 0) > 30 {
        print(w[kCGWindowNumber as String] as! Int); break
    }
}
SWIFT
)
[ -n "$id" ] || { echo "Trading Clock window not found" >&2; exit 1; }
screencapture -x -o -l "$id" "$out"
echo "$out"
