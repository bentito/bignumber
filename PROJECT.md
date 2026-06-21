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

### Step 2.a: Automated Device Discovery [Completed]
**Goal:** Implement an automatic discovery mechanism (e.g., UDP multicast/SSDP beacons or subnet sweeps) so the workstation ScoreKeeper TUI can automatically locate the Kindle's IP address without requiring manual entry.

**Implementation Details:**
*   **Multi-Protocol Shotgun Beacon:** Implemented a background UDP beacon loop in `show_number.sh` that broadcasts a `KINDLE_BIGNUM_BEACON` payload every 2 seconds. To bypass Starlink/mesh Wi-Fi band segregation (which drops standard `255.255.255.255` broadcasts), the script dynamically resolves the directed subnet broadcast IP (e.g., `192.168.1.255`), broadcasting to both it and `224.0.0.1` (All Hosts multicast) and `239.255.255.250` (SSDP) over the air.
*   **High-Speed Concurrent Subnet Sweep:** Developed a 254-thread concurrent subnet scanner fallback inside `scorekeeper.py`. If the UDP listener times out after 2 seconds (due to firewall or router drop rules), the TUI instantly sweeps your entire `/24` local network prefix on port 5000 in exactly **0.13 seconds**, natively and reliably bypassing any broadcast drops.
*   **Graceful Manual Fallback:** If both auto-discovery layers are blocked, the TUI gracefully presents an interactive prompt to let the user manually type the Kindle's Wi-Fi IP and hit Enter, connecting immediately without requiring an app restart.

### Step 3: Boot-Time Auto-Launch & State Initialization
**Goal:** Assume complete control of the Kindle's boot cycle such that the `bignumber` app auto-launches on boot, bypasses the standard home/Kindle library UI, and immediately displays a starting score of "0".

**Requirements:**
*   **Upstart/Init Integration:** Hook the Kindle's native upstart manager (e.g., `/etc/init/` or custom boot scripts like `/etc/rc.local`) to launch the `bignumber` web server daemon and fullscreen display script immediately during the system boot phase.
*   **UI Bypass:** Disable or suppress the standard Kindle system booklets (`cvm`, `appmgrd`, or `pillow` UI launcher layers) upon boot to prevent them from drawing over our big number or locking the framebuffer.
*   **Default State Initialization:** Settle immediately on showing a massive, centered "0" on the screen, starting the background discovery beacons, and transitioning the device into a stateless, low-power listen mode.
*   **External Command Ready:** Wait silently for score sync and display update requests sent remotely from the ScoreKeeper app.

### Step 4: P2P SCOREBOARD SETUP MODE & SEQUENTIAL LEADER ELECTION
**Goal:** Implement an intelligent, peer-to-peer setup mode where multiple Kindles turned on in proximity automatically discover each other, negotiate their respective slots on the baseball scoreboard, and display setup helpers before transitioning to game mode.

**Requirements:**
*   **P2P Peer Discovery:** Upon booting, each Kindle's `bignumber` app must use the same concurrent subnet-sweeping and beaconing discovery methods to scan the `/24` subnet, locating any other active `bignumber` Kindles.
*   **Sequential Leader Election (The Setup Walkthrough):**
    *   **Kindle 1 (The Leader):** The first Kindle powered on discovers no other peers. It designates itself as Slot 1 and displays a giant, helpful **"Top of the 1st"** setup instruction on its screen, indicating where on the physical scoreboard frame it should be hung.
    *   **Kindle 2 (The Follower):** The next Kindle turned on scans the network, discovers Kindle 1 already active, elects itself as Slot 2, and displays **"Bottom of the 1st"** on its screen.
    *   **Kindles 3+:** Subsequent Kindles continue this peer-election chain sequentially (**"Top of the 2nd"**, **"Bottom of the 2nd"**, etc.) as they are hung on the scoreboard frame.
*   **Central TUI Sync & "Done with Setup" Handshake:**
    *   The workstation ScoreKeeper TUI (or the future mobile app) connects to the elected leader and pulls the sequenced peer IP list.
    *   When the human operator is done hanging the screens, the ScoreKeeper app transmits a unicast `"Done with Setup"` HTTP packet to the Kindle network.
    *   Upon receiving the handshake, all Kindles instantly transition from setup-help displays to showing their respective initial score digits (e.g. "0") and wait for active game-score updates.