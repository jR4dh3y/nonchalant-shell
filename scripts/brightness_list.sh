#!/usr/bin/env bash
# Script to list all monitors and their current brightness
# Outputs format: MonitorName:Brightness

# Check for internal displays using brightnessctl (backlight devices only)
if command -v brightnessctl &> /dev/null; then
    DEVICES=$(brightnessctl -l 2>/dev/null | grep "backlight" | awk -F"'" '{print $2}')
    for device in $DEVICES; do
        CURRENT=$(brightnessctl -d "$device" g 2>/dev/null)
        MAX=$(brightnessctl -d "$device" m 2>/dev/null)
        if [ -n "$CURRENT" ] && [ -n "$MAX" ] && [ "$MAX" -gt 0 ]; then
            PERCENT=$(( CURRENT * 100 / MAX ))
            # Match the internal backlight to Niri's eDP output.
            MONITOR_NAME=$(niri msg -j outputs 2>/dev/null | jq -r 'keys[] | select(contains("eDP"))' | head -1)
            if [ -z "$MONITOR_NAME" ]; then
                MONITOR_NAME="eDP-1"
            fi
            echo "${MONITOR_NAME}:${PERCENT}"
        fi
    done
fi

# Check for external displays using ddcutil
if command -v ddcutil &> /dev/null; then
    CURRENT_BUS=""
    CURRENT_CONNECTOR=""
    
    while IFS= read -r line; do
        if [[ "$line" =~ I2C\ bus:.*-([0-9]+)$ ]]; then
            CURRENT_BUS="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ DRM\ connector:.*card[0-9]+-(.+)$ ]]; then
            CURRENT_CONNECTOR="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^$ ]] && [ -n "$CURRENT_BUS" ] && [ -n "$CURRENT_CONNECTOR" ]; then
            # End of display block, get brightness
            BRIGHTNESS=$(ddcutil -b "$CURRENT_BUS" getvcp 10 --brief 2>/dev/null | awk '{print $4}')
            if [ -n "$BRIGHTNESS" ]; then
                echo "${CURRENT_CONNECTOR}:${BRIGHTNESS}"
            fi
            CURRENT_BUS=""
            CURRENT_CONNECTOR=""
        fi
    done < <(ddcutil detect --brief 2>/dev/null; echo "")
fi
