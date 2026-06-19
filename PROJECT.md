# Project: Kindle Big Number Display

## Project Overview
This project builds a custom KUAL (Kindle Unified Application Launcher) extension for a 4th Generation Kindle (Firmware 4.1.4). The core objective is to create a lightweight tool that displays a highly visible, full-screen number on the e-ink display. 

The project is maintained on macOS, version-controlled via Git, and uses a `gemini-cli` agent workspace for iterative development.

---

## Infrastructure & Makefile Targets

The deployment loop relies on a simple Makefile to safely transfer files to the Kindle's USB mass storage volume while enforcing the strict file formats required by the legacy Linux environment.

*   **`make deploy`**
    *   **What it does:** Syncs the local `src/extensions/bignumber/` directory to `/Volumes/Kindle/extensions/bignumber/`.
    *   **Requirements:** Must verify the Kindle is actively mounted. It must enforce execution permissions (`chmod +x`) on all shell scripts during the transfer. It should also scan for and warn about Windows CRLF line endings, as they will fatally crash the script execution on the Kindle.
*   **`make clean`**
    *   **What it does:** Cleans the local workspace of temporary macOS artifacts (e.g., `.DS_Store` files) to prevent them from cluttering the Kindle's file system during deployment.

---

## Development Methodology

1.  **Iterative Scripting:** The extension logic will be written in standard POSIX shell scripting (`show_number.sh`), mapped to the KUAL interface via `menu.json`.
2.  **Deployment Loop:** Modify the source in `src/`, run `make deploy`, safely eject the Kindle, and test the execution natively via the KUAL menu.
3.  **Graceful Recovery:** The Kindle 4 framework (`appmgrd` and `eink_test`) can hang if the framebuffer is locked incorrectly. All scripts must ensure the display state is cleanly exited or can be overridden by a physical button press (like the Home button) to prevent requiring a hard reboot.

---

## Roadmap

### Step 1: Full-Screen Number Display [Completed]
**Goal:** Display a single, massive number that occupies the entire 600x800 e-ink screen. 

**Implementation Details:**
*   **Asset Generation:** Designed an automated, self-contained Python script (`scripts/generate_images.py`) that uses macOS system fonts (Helvetica/Arial) to generate 600x800 8-bit grayscale PNGs (0-9) with mathematical centering and auto-scaling.
*   **Control Logic:** Created `src/extensions/bignumber/show_number.sh` using POSIX-compliant scripting with LF line endings. It manages power management (`com.lab126.powerd preventScreenSaver`), clears the screen via `eips -c` to eliminate ghosting, renders the image fullscreen via `eips -g`, and blocks cleanly using `waitforkey`.
*   **Safety & Build System:** Created a Makefile to set up the Python venv, generate images, perform Windows CRLF syntax checks, verify Kindle USB mount point activity, enforce executable permissions, and safely sync via rsync.
*   **Integration:** Provided KUAL metadata mapping inside `config.xml` and organized the menu UI inside `menu.json` using a clean nested sub-menu.

### Step 2: Network-Driven ScoreKeeper Control [Completed]
**Goal:** Establish a network listener on the Kindle to allow a command-line Python TUI (the "ScoreKeeper" app placeholder) running on a workstation to remotely control the displayed big number over the network.

**Implementation Details:**
*   **Embedded Static Server:** Packaged a pre-compiled ARMv7l static Linux BusyBox binary (`bin/busybox`) containing both full netcat listen (`CONFIG_NC_SERVER=yes`) and HTTPD server (`CONFIG_HTTPD=yes`) directly inside our extension directory. This bypasses all stock Kindle BusyBox limitations and removes any jailbreak-specific dependencies.
*   **Zero-Loop CGI Architecture:** Redesigned the background listener into a loop-free `busybox httpd` web server daemon listening on port 5000. It routes requests to a CGI script (`www/cgi-bin/cmd.sh`), executing instantly and exiting with a 0% idle CPU footprint, completely eliminating watchdog crash reboots.
*   **Firewall Hole-Punching:** Resolved Wi-Fi packet drops by adding temporary absolute-path firewall rules (`/usr/sbin/iptables -I INPUT 1`) for ICMP and port 5000 upon app launch, securely closing them on exit.
*   **Python ScoreKeeper TUI:** Created `scripts/scorekeeper.py` with an interactive, colored console scoreboard. It uses Python's native `urllib.request` to send stateless HTTP requests, maintaining perfect score synchronization. Added a custom regex `pad_colored()` padding function to ignore hidden ANSI codes and perfectly align borders.
*   **Hardened Build & Recovery:** Updated `Makefile` with automatic `dot_clean -m` metadata scrubbers on deployment to completely block macOS AppleDouble file corruption, and added a deep `make full-reset` emergency target to restore the launcher from Downloads and clean RAM caches.

### Step 2.a: Automated Device Discovery (Pending)
**Goal:** Implement an automatic discovery mechanism (e.g., UDP multicast/SSDP beacons or subnet sweeps) so the workstation ScoreKeeper TUI can automatically locate the Kindle's IP address without requiring manual entry.

**Requirements:**
*   **Kindle Beacon:** Modify the Kindle network listener daemon to periodically broadcast a UDP beacon packet (e.g., on port 5001) containing its device ID and IP address when active.
*   **Workstation Auto-Discovery:** Update the Python ScoreKeeper TUI to listen for these UDP beacons at startup, automatically extracting and connecting to the Kindle's active IP address.
*   **Graceful Fallback:** Fall back to manual IP entry or the standard fallback USB network IPs if no beacons are detected within 5 seconds.

### Step 3: Interactive Physical Control Backup (Pending)
*To be defined: Creating an on-device physical button control loop as a backup interface when network access is unavailable.*