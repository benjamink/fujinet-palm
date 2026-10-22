#!/bin/sh
# Install FujiNet Palm apps by HotSync, over USB (Visor cradle, via palm-sync)
# or a serial cradle (Palm III/V etc., via pilot-link's pilot-xfer).
# Run it, then press the HotSync button on the cradle.
#
# Usage: tools/install-apps.sh [-u | -s PORT] [app|file.prc ...]
#   -u        USB HotSync (default), through tools/install-prc.sh
#   -s PORT   serial HotSync on PORT, e.g. /dev/ttyUSB0 or /dev/cu.usbserial-X
#   app       a name under palm/apps (fnlink, fujiconfig, weather, ...),
#             fnconfig for fujiconfig, netshim for fnnetlib.prc, or a path
#             to a .prc/.pdb. Default: fnlink fujiconfig
#
# Build the apps first (see README). A serial install needs the port free:
# stop fujinet-pc if it is using the same port.
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)

usage() {
    sed -n '6,11s/^# \{0,1\}//p' "$0" >&2
    exit 2
}

PORT=
while getopts us:h opt; do
    case $opt in
    u) PORT= ;;
    s) PORT=$OPTARG ;;
    *) usage ;;
    esac
done
shift $((OPTIND - 1))
[ $# -gt 0 ] || set -- fnlink fujiconfig

# Replace each argument with its file, keeping paths with spaces intact
n=$#
while [ $n -gt 0 ]; do
    app=$1
    shift
    n=$((n - 1))
    case $app in
    *.prc|*.pdb|*.PRC|*.PDB) f=$app ;;
    fnconfig) f=$ROOT/palm/apps/fujiconfig/fujiconfig.prc ;;
    netshim|fnnetlib) f=$ROOT/palm/netshim/fnnetlib.prc ;;
    *) f=$ROOT/palm/apps/$app/$app.prc ;;
    esac
    if [ ! -f "$f" ]; then
        echo "Not found: $f (build it first, see README)" >&2
        exit 1
    fi
    set -- "$@" "$f"
done

if [ -z "$PORT" ]; then
    exec "$ROOT/tools/install-prc.sh" "$@"
fi

if ! command -v pilot-xfer >/dev/null 2>&1; then
    echo "pilot-xfer not found: install pilot-link" >&2
    exit 1
fi
if [ ! -e "$PORT" ]; then
    echo "No such port: $PORT" >&2
    exit 1
fi
if command -v lsof >/dev/null 2>&1; then
    HOLDER=$(lsof -t "$PORT" 2>/dev/null || true)
    if [ -n "$HOLDER" ]; then
        echo "$PORT is in use by:" >&2
        ps -o pid=,command= -p $HOLDER >&2 || true
        echo "Stop it (e.g. fujinet-pc) and try again." >&2
        exit 1
    fi
fi

echo "Waiting on $PORT: press the HotSync button on the cradle (Ctrl-C to cancel)"
pilot-xfer -p "$PORT" -i "$@"
