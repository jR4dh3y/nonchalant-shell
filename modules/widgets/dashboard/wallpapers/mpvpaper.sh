#!/usr/bin/env bash

if [ -z "$1" ]; then
	echo "Use: $0 /path/to/wallpaper [shader_path] [monitor_target] [mode]"
	exit 1
fi

WALLPAPER="$1"
SHADER="$2"
MONITOR="${3:-ALL}"
MODE="${4:-crop}"

# When a specific monitor is targeted, we don't kill all mpvpaper instances,
# just the one for that monitor if possible. However mpvpaper doesn't
# natively support killing by monitor easily via pkill.
# For now, we'll kill by checking the command line args if MONITOR != ALL.
# We must avoid killing this script itself, so we filter by the exact executable name.
if [ "$MONITOR" = "ALL" ]; then
    pkill -x "mpvpaper" 2>/dev/null
else
    pgrep -x mpvpaper | while read -r pid; do
        if ps -p "$pid" -o args= | grep -q "$MONITOR"; then
            kill "$pid" 2>/dev/null
        fi
    done
fi
SOCKET="/tmp/nonchalant_mpv_socket_${MONITOR}"

case "$MODE" in
    fit)
        DISPLAY_OPTS="keepaspect=yes panscan=0.0"
        ;;
    stretch)
        DISPLAY_OPTS="keepaspect=no panscan=0.0"
        ;;
    center)
        DISPLAY_OPTS="keepaspect=yes panscan=0.0 video-unscaled=yes video-align-x=0.5 video-align-y=0.5"
        ;;
    *)
        DISPLAY_OPTS="keepaspect=yes panscan=1.0"
        ;;
esac

MPV_OPTS="no-audio loop hwdec=auto scale=bilinear interpolation=no video-sync=display-resample $DISPLAY_OPTS video-scale-x=1.0 video-scale-y=1.0 load-scripts=no input-ipc-server=$SOCKET"

# Si el shader no está vacío y el archivo existe, agregarlo a MPV_OPTS
if [ -n "$SHADER" ] && [ -f "$SHADER" ]; then
	MPV_OPTS="$MPV_OPTS glsl-shaders=$SHADER"
fi

nohup mpvpaper -o "$MPV_OPTS" "$MONITOR" "$WALLPAPER" >/tmp/mpvpaper.log 2>&1 &
