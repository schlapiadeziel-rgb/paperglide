#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
: "${ART_RAW:?Set ART_RAW to the original base-game masters directory}"
: "${ART_RAW_V2:?Set ART_RAW_V2 to the original v2 masters directory}"
test -d "$ART_RAW"
test -d "$ART_RAW_V2"
bash tools/art/process_all.sh
bash tools/art/process_v2.sh
python3 tools/build_segments.py
