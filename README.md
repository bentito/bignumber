# Kindle Big Number Display

A custom, lightweight KUAL (Kindle Unified Application Launcher) extension built specifically for the **4th Generation Kindle (Non-touch, Firmware 4.1.4)**. This tool displays a highly visible, full-screen, massive number on the 600x800 e-ink display. It is designed to bypass standard system dialog boxes, eliminate e-ink ghosting, and allow a clean escape/recovery mechanism back to the KUAL interface.

---

## Directory Structure

The project workspace is organized as follows:

```text
.
├── Makefile                     # Handles local builds, syntax checks, and deployment
├── PROJECT.md                   # Core development roadmap and step definitions
├── AGENTS.md                    # Special guidelines for development assistants
├── README.md                    # This overview and guide
├── scripts/
│   └── generate_images.py       # Auto-scaling macOS font rendering script (Pillow-based)
└── src/
    └── extensions/
        └── bignumber/
            ├── config.xml       # KUAL metadata configuration
            ├── menu.json        # KUAL hierarchical sub-menu config
            └── show_number.sh   # Main POSIX shell execution script (LF line endings)
```

---

## Technical Architecture

### 1. Grayscale Asset Generation (`scripts/generate_images.py`)
To prevent requiring heavy compilation or image-rendering packages on the Kindle's limited CPU/memory, we pre-generate high-quality grayscale images on the developer's machine:
*   **Source:** Uses standard macOS system fonts (Helvetica/Arial).
*   **Auto-Scaling:** An iterative bounding-box check starts with a massive `700pt` font size and scales down in steps of `10pt` until the digit fits within a `500x700` box (leaving a `50px` protective safety margin on all sides).
*   **Mathematical Centering:** Calculates precise coordinates to offset font metrics and align the exact pixel bounding box of the number to the center of the `600x800` canvas.
*   **Format:** Generates optimized **8-bit grayscale PNGs with no transparency** (mode `L`), which are natively compatible with Kindle's `eips` command.

### 2. Full-Screen Shell Execution (`show_number.sh`)
The POSIX-compliant shell script handles direct hardware and framework events on the Kindle:
1.  **Sleep Prevention:** Disables power-management-induced sleep using:
    `lipc-set-prop -i com.lab126.powerd preventScreenSaver 1`
2.  **Anti-Ghosting Clear:** Executes `eips -c` and sleeps for `1s` to fully clear the screen and eliminate lingering ink artifacts.
3.  **Direct Framebuffer Drawing:** Invokes `eips -g images/<digit>.png` to draw the pre-generated image fullscreen.
4.  **Input Blocking:** Blocks execution using the native `waitforkey` binary (reading directly from `/dev/input/event*`). If `waitforkey` is not present, it gracefully falls back to showing the number for `5` seconds before exiting.
5.  **Graceful Recovery:** Upon any physical keypress (such as D-Pad, page turns, or the Home button):
    *   Re-enables power-saving screensavers (`preventScreenSaver 0`).
    *   Clears the screen (`eips -c`).
    *   Triggers a full-screen refresh cycle (`eips -f`) to cleanly restore Kindle's native Home or KUAL launcher menus.

### 3. KUAL Menu Mapping (`config.xml` & `menu.json`)
*   **`config.xml`** provides basic extension identification to KUAL.
*   **`menu.json`** organizes the interface under a nested submenu titled **"Big Number Display"** containing 10 options (**"Show 0"** through **"Show 9"**), passing the corresponding digit parameter to the show script. This prevents top-level menu clutter.

---

## Build, Validation & Deployment

The workflow is managed via a strict macOS-friendly `Makefile`:

### 1. Build and Generate Assets
Creates a local python virtual environment (`.venv`), installs the standard `Pillow` library, and renders the fullscreen image assets:
```bash
make images
```

### 2. Run Pre-flight Syntax Checks
Enforces POSIX/Linux-compatible formatting:
*   **CRLF Check:** Scans files for Windows carriage returns (`\r`), which will fatally crash scripts on legacy Linux.
    ```bash
    make check-crlf
    ```
*   **Wait Mount Check:** Verifies if a physical Kindle is mounted at `/Volumes/Kindle/`. If not connected, it blocks and prompts you to connect it via USB.
    ```bash
    make wait-mount
    ```

### 3. Deploy to Kindle
Checks if the Kindle is mounted (prompting you to connect it if not), enforces execution permissions (`chmod +x`), performs syntax pre-flight checks, copies the extension using `rsync`, flushes filesystem caches, sleeps, and then safely ejects the volume via macOS `diskutil`:
```bash
make deploy
```

### 4. Clean Artifacts
Removes the local Python virtual environment, all generated `.png` assets, and `.DS_Store` garbage:
```bash
make clean
```

---

## Quick Start
1.  Run the interactive deploy target in your terminal:
    ```bash
    make deploy
    ```
2.  Connect your Kindle 4 via USB when prompted.
3.  The Makefile will automatically copy the files, sync buffers, safely eject the Kindle, and notify you when it is safe to unplug!
4.  Launch KUAL on your Kindle and tap:
    **`Big Number Display` ➔ `Show X`**
5.  To exit the full-screen display back to KUAL, press any physical key (such as Home, Back, D-Pad, or Page Turn).
