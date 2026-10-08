#!/bin/sh
# Open prepared native scenes; locally extracted r2 is optional for viewing.
set -eu
workshop_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
workshop_runtime="$workshop_root/build/radare2-runtime"
if [ -z "${RHUN_RADARE2:-}" ] && [ -x "$workshop_runtime/usr/bin/r2" ]; then
    export RHUN_RADARE2="$workshop_runtime/usr/bin/r2"
    export LD_LIBRARY_PATH="$workshop_runtime/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi
workshop_scene=${1:-"$workshop_root/build/radare-workshop/mem_alloc-memory.rhun-canvas"}
if [ ! -f "$workshop_scene" ]; then
    echo "Scene missing: $workshop_scene" >&2
    echo 'Prepare with python3 tools/radare-workshop.py; see docs/rhun-radare2-walkthrough-ru.md' >&2
    exit 1
fi
exec "$workshop_root/build/rhun" "$workshop_root" "$workshop_scene"
