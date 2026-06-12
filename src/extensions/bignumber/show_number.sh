#!/bin/sh
# Standard POSIX shell script for Kindle 4 (Firmware 4.1.4)
# Kindle Big Number Display - Full-Screen Rendering with Input Loop

# Initialize screen logging row
log_row=0
log_screen() {
    # Print text at col 0, row log_row using native eips
    eips 0 $log_row "$1"
    # Increment log_row for next message
    log_row=$((log_row + 1))
}

# Clear screen at the very start to display debug messages clearly
eips -c
sleep 1

log_screen "[DEBUG] Big Number Display Initializing..."

# Check if a number argument was passed
if [ -z "$1" ]; then
    log_screen "[ERROR] No digit argument passed!"
    sleep 5
    exit 1
fi

DIGIT="$1"
log_screen "[DEBUG] Target digit: $DIGIT"

# Resolve absolute path of the script directory portably
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
log_screen "[DEBUG] Script Dir: $SCRIPT_DIR"

IMAGE_PATH="${SCRIPT_DIR}/images/${DIGIT}.png"
log_screen "[DEBUG] Image Path: $IMAGE_PATH"

# Verify the requested image exists
if [ ! -f "$IMAGE_PATH" ]; then
    log_screen "[ERROR] Image not found at path!"
    sleep 5
    exit 1
fi
log_screen "[DEBUG] Image verified exists."

# 1. Prevent the Kindle from going to sleep or showing screensaver
log_screen "[DEBUG] Disabling screensaver..."
lipc-set-prop -i com.lab126.powerd preventScreenSaver 1
log_screen "[DEBUG] Screensaver disabled successfully."

# Let the user read the debug logs for 3 seconds before clearing to render
log_screen "[DEBUG] Clearing screen and rendering in 3 seconds..."
sleep 3

# 2. Clear the screen cleanly to prevent e-ink ghosting
eips -c
sleep 1

# 3. Render the massive number image fullscreen
eips -g "$IMAGE_PATH"

# 4. Flush and Wait for a physical button press
# If waitforkey is available, use it (filtering for key-down state 1)
# Otherwise, use a zero-dependency read of /dev/input/event0 (general buttons)
if command -v waitforkey >/dev/null 2>&1; then
    while true; do
        event=$(waitforkey)
        set -- $event
        keycode="$1"
        state="$2"
        
        # Check if the state is '1' (key down / pressed)
        if [ "$state" = "1" ]; then
            break
        fi
    done
elif [ -e /dev/input/event0 ]; then
    # Zero-dependency hardware block:
    # event0 contains general keys (Home, Back, Menu, Keyboard, Page Turns)
    # Each event is 16 bytes. Reading 32 bytes (2 events) blocks until a key
    # is pressed (down) and released (up).
    # We sleep 1 second first to flush any pending releases from the selection.
    sleep 1
    dd if=/dev/input/event0 bs=16 count=2 >/dev/null 2>&1
else
    # Ultimate fallback if no event device is readable
    sleep 5
fi

# 5. Graceful Recovery: restore original system state and refresh screen
lipc-set-prop -i com.lab126.powerd preventScreenSaver 0
eips -c
lipc-set-prop com.lab126.winmgr refresh 1
