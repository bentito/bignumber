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

### Step 2: Interactive Number Manipulation (Increment/Decrement Loop)
**Goal:** Enable changing the displayed fullscreen number dynamically using physical buttons without returning to the KUAL menu.

**Requirements:**
*   Read which physical key is pressed on the Kindle 4 (such as D-Pad Up, Down, Left, Right, or Page Turn keys).
*   Increment the displayed number (0 to 9, wrapping around) when D-Pad Up / Right or Page Next is pressed.
*   Decrement the displayed number when D-Pad Down / Left or Page Prev is pressed.
*   Refresh and render the new number's full-screen image cleanly with minimal latency.
*   Provide a dedicated button (like the Back button or Home button) to cleanly break out of the loop and gracefully restore the system display and power states.

### Step 3: [Pending]
*To be defined once interactive control loop is successfully achieved and validated.*