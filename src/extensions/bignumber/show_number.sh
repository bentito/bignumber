#!/bin/sh
# Standard POSIX shell script for Kindle 4 (Firmware 4.1.4)
# Kindle Big Number Display - Full-Screen Rendering with Network Control

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

# Check if a starting number argument was passed
if [ -z "$1" ]; then
    log_screen "[ERROR] No starting digit argument passed!"
    sleep 5
    exit 1
fi

DIGIT="$1"
log_screen "[DEBUG] Starting digit: $DIGIT"

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

# Display local network IPs for convenience
WLAN_IP=$(ifconfig wlan0 2>/dev/null | grep "inet addr" | awk '{print $2}' | cut -d: -f2)
USB_IP=$(ifconfig usb0 2>/dev/null | grep "inet addr" | awk '{print $2}' | cut -d: -f2)
WLAN_BCAST=$(ifconfig wlan0 2>/dev/null | grep "Bcast" | awk '{print $3}' | cut -d: -f2)
[ -z "$WLAN_BCAST" ] && WLAN_BCAST="255.255.255.255"
USB_BCAST=$(ifconfig usb0 2>/dev/null | grep "Bcast" | awk '{print $3}' | cut -d: -f2)
[ -z "$USB_BCAST" ] && USB_BCAST="192.168.15.255"

if [ -n "$WLAN_IP" ]; then
    log_screen "[DEBUG] Wi-Fi IP : $WLAN_IP"
fi
if [ -n "$USB_IP" ]; then
    log_screen "[DEBUG] USBnet IP: $USB_IP"
fi
if [ -z "$WLAN_IP" ] && [ -z "$USB_IP" ]; then
    log_screen "[DEBUG] Kindle IP: Unknown"
fi
log_screen "[DEBUG] Listener Port: 5000"

# Let the user read the debug logs for 4 seconds before clearing to render
log_screen "[DEBUG] Clearing screen and listening in 4 seconds..."
sleep 4

# 2. Clear the screen cleanly to prevent e-ink ghosting
eips -c
sleep 1

# 3. Render the starting massive number image fullscreen
eips -g "$IMAGE_PATH"

# 4. State Management and Background Network Listener Loop
# Punch a hole in the Kindle's strict default iptables firewall for TCP and ICMP
log_screen "[DEBUG] Applying iptables TCP rule..."
ipt_err=$(/usr/sbin/iptables -I INPUT 1 -p tcp --dport 5000 -j ACCEPT 2>&1)
if [ -n "$ipt_err" ]; then
    log_screen "[WARN] iptables tcp: $ipt_err"
fi

log_screen "[DEBUG] Applying iptables ICMP rule..."
ipt_err2=$(/usr/sbin/iptables -I INPUT 1 -p icmp -j ACCEPT 2>&1)
if [ -n "$ipt_err2" ]; then
    log_screen "[WARN] iptables icmp: $ipt_err2"
fi

STATE_FILE="/tmp/bignumber_current"
echo "$DIGIT" > "$STATE_FILE"

# Locate our embedded, full-featured ARM BusyBox binary.
# This static binary contains both full nc -l and httpd cgi server applets,
# bypassing all stock Kindle and jailbreak-independent limitations.
BUSYBOX="${SCRIPT_DIR}/bin/busybox"
if [ -f "$BUSYBOX" ]; then
    log_screen "[DEBUG] Using embedded static BusyBox."
    # Ensure it has execute permissions on the Kindle filesystem
    chmod +x "$BUSYBOX" 2>/dev/null || true
else
    BUSYBOX="busybox"
    log_screen "[WARN] Embedded BusyBox not found! Fallback to stock."
fi

# Start busybox httpd as a background daemon listening on port 5000
log_screen "[DEBUG] Starting HTTPD server on port 5000..."
# Forcefully kill any process occupying or trying to listen on Port 5000 (like nc or httpd)
# We scan /proc directly to find any command lines containing "5000" or "httpd"
# Uses substring replacement instead of command substitution for environment safety
for cmd_file in /proc/[0-9]*/cmdline; do
    if grep -q "5000\|httpd" "$cmd_file" 2>/dev/null; then
        pid_dir=${cmd_file%/cmdline}
        pid=${pid_dir#/proc/}
        if [ -n "$pid" ] && [ "$pid" != "$$" ]; then
            kill -9 "$pid" 2>/dev/null || true
        fi
    fi
done

# Clean up any previously hung httpd listeners using our PID file or killall
if [ -f /tmp/bignumber_httpd.pid ]; then
    cat /tmp/bignumber_httpd.pid | xargs kill -9 2>/dev/null || true
    rm -f /tmp/bignumber_httpd.pid
fi
killall httpd 2>/dev/null || true
rm -f /tmp/httpd_err

# Start httpd in the foreground (-f) inside a background subshell
# to cleanly capture its exact process ID in $!
$BUSYBOX httpd -f -p 5000 -h "${SCRIPT_DIR}/www" 2>/tmp/httpd_err &
HTTPD_PID=$!
echo "$HTTPD_PID" > /tmp/bignumber_httpd.pid

if [ -s /tmp/httpd_err ]; then
    err_msg=$(cat /tmp/httpd_err | head -n 1)
    eips 0 20 "HTTPD ERR: $err_msg"
fi

# Start background UDP broadcast discovery beacon on port 5001
log_screen "[DEBUG] Starting UDP discovery beacon on port 5001..."
log_screen "[DEBUG]   Wi-Fi IP : ${WLAN_IP:-None}"
log_screen "[DEBUG]   Subnet BC: ${WLAN_BCAST:-None}"
log_screen "[DEBUG]   USBnet IP: ${USB_IP:-None}"
log_screen "[DEBUG]   USB BC IP: ${USB_BCAST:-None}"

rm -f /tmp/beacon_err
(
    while true; do
        # Broadcast to directed Wi-Fi subnet broadcast (WLAN_BCAST)
        # We also broadcast to All Hosts Multicast (224.0.0.1) and SSDP (239.255.255.250)
        # to ensure mesh/Starlink routers bypass filtering and route the packets cleanly
        if [ -n "$WLAN_IP" ]; then
            echo "KINDLE_BIGNUM_BEACON" | $BUSYBOX nc -w 1 -u "$WLAN_BCAST" 5001 >/tmp/beacon_err 2>&1
            echo "KINDLE_BIGNUM_BEACON" | $BUSYBOX nc -w 1 -u 255.255.255.255 5001 >>/tmp/beacon_err 2>&1
            echo "KINDLE_BIGNUM_BEACON" | $BUSYBOX nc -w 1 -u 224.0.0.1 5001 >>/tmp/beacon_err 2>&1
            echo "KINDLE_BIGNUM_BEACON" | $BUSYBOX nc -w 1 -u 239.255.255.250 5001 >>/tmp/beacon_err 2>&1
        fi
        
        # Broadcast specifically to the directed USBNetwork subnet broadcast
        if [ -n "$USB_IP" ]; then
            echo "KINDLE_BIGNUM_BEACON" | $BUSYBOX nc -w 1 -u "$USB_BCAST" 5001 >>/tmp/beacon_err 2>&1
        fi
        
        # Display any background UDP socket or broadcast errors on screen
        if [ -s /tmp/beacon_err ]; then
            bcn_err=$(cat /tmp/beacon_err | head -n 1)
            eips 0 22 "BCN ERR: $bcn_err"
        fi
        
        sleep 2
    done
) &
BEACON_PID=$!

# 5. Flush and Wait for a physical button press (Exit Trigger)
if command -v waitforkey >/dev/null 2>&1; then
    while true; do
        event=$(waitforkey)
        set -- $event
        state="$2"
        if [ "$state" = "1" ]; then
            break
        fi
    done
elif [ -e /dev/input/event0 ]; then
    # Zero-dependency hardware block: wait for any button press/release
    sleep 1
    dd if=/dev/input/event0 bs=16 count=2 >/dev/null 2>&1
else
    # Ultimate fallback if no event device is readable (wait up to 10 hours)
    sleep 36000
fi

# 6. Graceful Recovery: Terminate network listener and restore system states
kill -9 "$BEACON_PID" 2>/dev/null || true
killall httpd 2>/dev/null || true

# Securely close the firewall holes
/usr/sbin/iptables -D INPUT -p tcp --dport 5000 -j ACCEPT 2>/dev/null || true
/usr/sbin/iptables -D INPUT -p icmp -j ACCEPT 2>/dev/null || true
rm -f /tmp/httpd_err
rm -f "$STATE_FILE"

lipc-set-prop -i com.lab126.powerd preventScreenSaver 0
eips -c
lipc-set-prop com.lab126.winmgr refresh 1
