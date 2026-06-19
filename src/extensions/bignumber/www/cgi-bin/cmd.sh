#!/bin/sh
# BusyBox HTTPD CGI Script for Kindle Big Number Display

# Output the mandatory HTTP headers
echo "HTTP/1.1 200 OK"
echo "Content-type: text/plain"
echo ""

# Extract the command from the query string (e.g., ?action=UP)
cmd=$(echo "$QUERY_STRING" | awk -F'=' '{print $2}')
[ -z "$cmd" ] && exit 0

STATE_FILE="/tmp/bignumber_current"
SCRIPT_DIR="/mnt/us/extensions/bignumber"

current=$(cat "$STATE_FILE" 2>/dev/null)
[ -z "$current" ] && current=0
new="$current"

case "$cmd" in
    UP|up)
        new=$(( (current + 1) % 10 ))
        ;;
    DOWN|down)
        new=$(( (current + 9) % 10 ))
        ;;
    [0-9])
        new="$cmd"
        ;;
esac

# If the digit changed, update state file and instruct eips to draw the new image
if [ "$new" != "$current" ]; then
    echo "$new" > "$STATE_FILE"
    eips -g "${SCRIPT_DIR}/images/${new}.png"
fi

# Return success to the client
echo "SUCCESS: ${new}"
