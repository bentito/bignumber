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
│   ├── generate_images.py       # Auto-scaling macOS font rendering script (Pillow-based)
│   └── scorekeeper.py           # Terminal-based workstation ScoreKeeper TUI controller
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

### 2. Full-Screen Shell Execution & Network Listener (`show_number.sh`)
The POSIX-compliant shell script handles direct hardware, input, and network events on the Kindle:
1.  **Sleep Prevention:** Disables power-management-induced sleep using:
    `lipc-set-prop -i com.lab126.powerd preventScreenSaver 1`
2.  **IP & State Detection:** Detects the Kindle's local IP address (Wi-Fi or USB network interface) and prints it on-screen along with the listener port (`5000`) for easy diagnostics.
3.  **Anti-Ghosting Clear & Draw:** Clears the screen via `eips -c` and draws the starting full-screen number via `eips -g`.
4.  **Background TCP Listener Loop:** Launches an asynchronous loop that restarts BusyBox netcat (`nc -l -p 5000`) on connection completion. It parses stateless incoming TCP commands (`UP`, `DOWN`, or specific score digits `0-9`), manages the current score state in `/tmp/bignumber_current`, and triggers rapid full-screen redrawing on change.
5.  **Clean Input Intercept:** Blocks on a foreground hardware loop (reading `/dev/input/event0` with `dd` or `waitforkey`). If any physical hardware key (like Back, Home, or Page Turn) is pressed on the Kindle, the foreground script terminates the background listener, deletes temporary states, and restores power savings.

### 3. Workstation ScoreKeeper TUI Controller (`scripts/scorekeeper.py`)
A standalone Python terminal-based TUI client that runs on the workstation:
*   **Aesthetics:** Implements a high-contrast, fully styled terminal dashboard with colored status indicators (green `[ONLINE / SENT]`, red `[OFFLINE]`, blue `[STANDBY]`), score borders, and custom keyboard instructions.
*   **Controls:** Captures single-key inputs in real-time (using termios/tty) without requiring Enter:
    *   `W` / `Up Arrow` / `Right Arrow` to increment the score.
    *   `S` / `Down Arrow` / `Left Arrow` to decrement the score.
    *   `0-9` to directly set the score.
    *   `Q` / `ESC` to quit.
*   **Resiliency:** Automatically maintains local state and sends the absolute digit over TCP socket streams to port `5000` to prevent state drift. If a network socket connection fails (timeout or refused), it displays a prominent colored warning without crashing.

### 4. KUAL Menu Mapping (`config.xml` & `menu.json`)
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

### 1. Deploy the Extension
1.  Run the interactive deploy target in your terminal:
    ```bash
    make deploy
    ```
2.  Connect your Kindle 4 via USB when prompted.
3.  The Makefile will automatically copy the files, sync buffers, safely eject the Kindle, and notify you when it is safe to unplug!

### 2. Launch the Kindle Network Listener
1.  Unplug your Kindle 4.
2.  Ensure your Kindle is connected to the same Wi-Fi network as your workstation (or setup Kindle's USB networking).
3.  Open **KUAL** on your Kindle and tap:
    **`Big Number Display` ➔ `Show X`** (select any starting number, e.g. Show 0).
4.  The on-screen debug log will print the Kindle's local IP address (e.g. `192.168.1.15` or standard USB-network `192.168.15.244`) and the port `5000`.
5.  After 4 seconds, the logs clear, and the starting number displays fullscreen. The background TCP listener is now active!

### 3. Run the Workstation ScoreKeeper TUI
1.  On your workstation terminal, launch the ScoreKeeper dashboard:
    ```bash
    make scorekeeper KINDLE_IP=192.168.x.x
    ```
    *(Replace `192.168.x.x` with the IP address printed on your Kindle screen during initialization. If using standard USB networking, you can simply run `make scorekeeper`.)*
2.  The beautiful, high-contrast terminal scoreboard will open. 
3.  Press **W** / **Up Arrow** / **Right Arrow** to increment, **S** / **Down Arrow** / **Left Arrow** to decrement, or keys **0-9** to set score digits directly! The Kindle will update fullscreen in real-time.
4.  Press **Q** or **ESC** in your workstation terminal to exit the ScoreKeeper TUI.
5.  Press any hardware key on your Kindle (Back, Home, Menu, or Page Turn) to terminate the network listener on the Kindle and cleanly return back to the KUAL menu.
