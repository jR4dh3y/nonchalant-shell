#!/usr/bin/env bash

# Kill notification daemons that may conflict
for daemon in dunst mako swaync; do
	if pgrep -x "$daemon" >/dev/null; then
		echo "Stopping $daemon..."
		pkill -x "$daemon"
	fi
done
