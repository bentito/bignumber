#!/bin/sh
# Kindle Big Number Display - Emergency Stop Action
# Forcefully terminates any orphaned background listeners and restores UI

# 1. Clear the screen to signal action
eips -c
eips 0 0 "Stopping all bignumber listeners..."

# 2. Forcefully kill background processes
killall -9 nc 2>/dev/null || true
killall -9 httpd 2>/dev/null || true

# 3. Clean up all temporary state files
rm -f /tmp/nc_out /tmp/nc_err /tmp/bignumber_nc_pid /tmp/httpd_err /tmp/bignumber_current

# 4. Restore original system power and screensaver settings
lipc-set-prop -i com.lab126.powerd preventScreenSaver 0

# 5. Clear screen and force the Window Manager to redraw KUAL
eips -c
eips 0 2 "All background listeners stopped successfully."
sleep 2
eips -c
lipc-set-prop com.lab126.winmgr refresh 1
