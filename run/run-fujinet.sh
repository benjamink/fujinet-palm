#!/bin/sh
# Run fujinet-pc (RS232 target) from this folder, with fnconfig.ini and SD/.
# The binary comes from FUJINET_BIN, else a fujinet-firmware checkout next to
# this repo, built with `./build.sh -p RS232` (it lands in build/dist/).
#
# Usage: run/run-fujinet.sh [-f FILE] [-i | -s PORT] [-w PORT] [-- fujinet args]
#   -f FILE   config file in run/ (default fnconfig.ini); a new one starts
#             as a copy of fnconfig.ini
#   -i        bus-over-IP on localhost:1985 (Visor bridge, emulator)
#   -s PORT   serial port, e.g. /dev/ttyUSB0 (Palm in a serial cradle)
#   -w PORT   web UI port (default 8000)
# -i and -s set just [BOIP] enabled and [Serial] port in the config file and
# leave the rest of it (host slots etc.) alone. With neither, the file is
# used as it is. Two copies can run at once with their own config files and
# web ports, e.g. a Palm on serial and a Visor over the bridge:
#   run/run-fujinet.sh -s /dev/ttyUSB0
#   run/run-fujinet.sh -f fnconfig-visor.ini -i -w 8001
cd "$(dirname "$0")" || exit 1
BIN=${FUJINET_BIN:-../../fujinet-firmware/build/dist/fujinet}
if [ ! -x "$BIN" ]; then
    echo "fujinet-pc not found at $BIN" >&2
    echo "Build it: (cd ../../fujinet-firmware && ./build.sh -p RS232), or set FUJINET_BIN" >&2
    exit 1
fi

# set_ini SECTION KEY VALUE: set one key in $CONFIG in place, keeping
# its CRLF line endings. Adds the key (or section) if it is missing.
set_ini() {
    awk -v sec="[$1]" -v key="$2" -v val="$3" '
        { cr = sub(/\r$/, "") ? "\r" : "" }
        function put() { printf "%s=%s%s\n", key, val, cr; done = 1 }
        /^\[/ {
            if (in_sec && !done) put()
            in_sec = ($0 == sec)
        }
        in_sec && index($0, key "=") == 1 { if (!done) put(); next }
        { printf "%s%s\n", $0, cr }
        END {
            if (in_sec && !done) put()
            else if (!done) { printf "%s%s\n", sec, cr; put() }
        }
    ' "$CONFIG" > "$CONFIG.tmp" && cat "$CONFIG.tmp" > "$CONFIG"
    rm -f "$CONFIG.tmp"
}

CONFIG=fnconfig.ini
MODE=
SERIAL=
WEB=
while getopts f:is:w: opt; do
    case $opt in
    f) CONFIG=$OPTARG ;;
    i) MODE=boip ;;
    s) MODE=serial; SERIAL=$OPTARG ;;
    w) WEB=$OPTARG ;;
    *) sed -n '6,11s/^# \{0,1\}//p' "$0" >&2; exit 2 ;;
    esac
done
shift $((OPTIND - 1))

if [ ! -f "$CONFIG" ]; then
    cp fnconfig.ini "$CONFIG" || exit 1
    echo "Created $CONFIG from fnconfig.ini"
fi
case $MODE in
boip) set_ini BOIP enabled 1
      echo "fujinet-pc ($CONFIG) on bus-over-IP" ;;
serial) set_ini BOIP enabled 0; set_ini Serial port "$SERIAL"
        echo "fujinet-pc ($CONFIG) on serial $SERIAL" ;;
esac
[ -z "$WEB" ] || set -- -u "http://0.0.0.0:$WEB" "$@"

"$BIN" -c "$CONFIG" -s SD "$@"
rc=$?
while [ $rc -eq 75 ]; do
    "$BIN" -c "$CONFIG" -s SD "$@"
    rc=$?
done
exit $rc
