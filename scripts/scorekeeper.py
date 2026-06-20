#!/usr/bin/env python3
import os
import sys
import socket
import termios
import tty
import re
import urllib.request
import threading
import time

DEFAULT_KINDLE_IPS = ["192.168.15.244", "192.168.2.2"]
PORT = 5000

# ANSI Terminal Color Escape Codes
CLR_RESET = "\033[0m"
CLR_BOLD = "\033[1m"
CLR_DIM = "\033[2m"
CLR_UNDERLINE = "\033[4m"

# Text Colors
CLR_RED = "\033[31m"
CLR_GREEN = "\033[32m"
CLR_YELLOW = "\033[33m"
CLR_BLUE = "\033[34m"
CLR_MAGENTA = "\033[35m"
CLR_CYAN = "\033[36m"
CLR_WHITE = "\033[37m"

# Background Colors for Highlight
BG_BLACK = "\033[40m"
BG_WHITE = "\033[47m"

def getch():
    """Reads a single raw character from the terminal without blocking or requiring Enter."""
    fd = sys.stdin.fileno()
    old_settings = termios.tcgetattr(fd)
    try:
        tty.setraw(sys.stdin.fileno())
        ch = sys.stdin.read(1)
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
    return ch

def get_key():
    """Reads keyboard input and parses ANSI arrow/escape sequences portably."""
    ch = getch()
    if ch == '\x1b':
        # Potential escape sequence
        try:
            fd = sys.stdin.fileno()
            old_settings = termios.tcgetattr(fd)
            tty.setraw(fd)
            ch2 = sys.stdin.read(1)
            if ch2 == '[':
                ch3 = sys.stdin.read(1)
                if ch3 == 'A': return 'UP'
                if ch3 == 'B': return 'DOWN'
                if ch3 == 'C': return 'RIGHT'
                if ch3 == 'D': return 'LEFT'
            return 'ESC'
        except Exception:
            return 'ESC'
        finally:
            termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
    return ch

def pad_colored(text, length, align="left"):
    """Pads a string with spaces to a given visible width, ignoring hidden ANSI color codes."""
    # Strip ANSI escape sequences using regex
    ansi_escape = re.compile(r'\x1b\[[0-9;]*m')
    visible_text = ansi_escape.sub('', text)
    visible_len = len(visible_text)
    
    if visible_len >= length:
        return text
        
    spaces_needed = length - visible_len
    if align == "left":
        return text + (" " * spaces_needed)
    elif align == "right":
        return (" " * spaces_needed) + text
    else: # center
        left_spaces = " " * (spaces_needed // 2)
        right_spaces = " " * (spaces_needed - len(left_spaces))
        return left_spaces + text + right_spaces

def send_command(ip, cmd):
    """Sends an HTTP GET command directly to the Kindle's HTTPD CGI listener."""
    url = f"http://{ip}:{PORT}/cgi-bin/cmd.sh?action={cmd}"
    try:
        req = urllib.request.Request(url)
        # Timeout is 1.5 seconds to keep the TUI extremely responsive
        with urllib.request.urlopen(req, timeout=1.5) as response:
            res_data = response.read().decode('utf-8')
            if "SUCCESS" in res_data:
                return True, "SUCCESS"
            return False, "ERROR"
    except urllib.error.URLError as e:
        # Check if timeout
        if isinstance(e.reason, socket.timeout):
            return False, "TIMEOUT"
        return False, "REFUSED"
    except Exception as e:
        return False, str(e)

def draw_tui(score, ip, last_status):
    """Clears the console and draws a beautifully designed, high-signal TUI scoreboard."""
    # Clear console (ANSI escape code)
    print("\033[H\033[J", end="")
    
    # Status styling
    if last_status == "SUCCESS":
        status_text = f"{CLR_GREEN}{CLR_BOLD}[ ONLINE / SENT ]{CLR_RESET}"
    elif last_status == "STANDBY":
        status_text = f"{CLR_BLUE}{CLR_BOLD}[ STANDBY ]{CLR_RESET}"
    elif last_status in ("TIMEOUT", "REFUSED"):
        status_text = f"{CLR_RED}{CLR_BOLD}[ OFFLINE / {last_status} ]{CLR_RESET}"
    else:
        status_text = f"{CLR_RED}{CLR_BOLD}[ ERR: {last_status} ]{CLR_RESET}"
        
    # Set the interior width of our scoreboard to exactly 56 columns
    W = 56
    
    # 1. Header rows
    row_title = pad_colored(f"{CLR_BOLD}{CLR_WHITE}KINDLE BIG NUMBER DISPLAY - SCOREKEEPER TUI", W, "center")
    row_info = pad_colored(f"Kindle IP: {CLR_YELLOW}{ip}{CLR_RESET}  |  Port: {CLR_YELLOW}{PORT}{CLR_RESET}", W, "left")
    row_net = pad_colored(f"Network  : {status_text}", W, "left")
    
    # 2. Main Game Score rows
    row_space = pad_colored("", W, "left")
    row_score_lbl = pad_colored(f"{CLR_BOLD}{CLR_WHITE}CURRENT GAME SCORE", W, "center")
    
    # Centered Score Box row definitions
    box_top_inner = f"┌─────────┐"
    box_val_inner = f"│    {score}    │"
    box_bot_inner = f"└─────────┘"
    
    # Color the boxes for maximum visual contrast (white on bold-red)
    row_box_top = pad_colored(f"{CLR_RED}{CLR_BOLD}{box_top_inner}{CLR_RESET}", W, "center")
    row_box_val = pad_colored(f"{CLR_RED}{CLR_BOLD}{box_val_inner}{CLR_RESET}", W, "center")
    row_box_bot = pad_colored(f"{CLR_RED}{CLR_BOLD}{box_bot_inner}{CLR_RESET}", W, "center")
    
    # 3. Control guidance rows
    row_ctrl_lbl = pad_colored(f"{CLR_BOLD}{CLR_WHITE}Controls:", W, "left")
    row_ctrl1 = pad_colored(f" {CLR_YELLOW}[W] / [Up Arrow] / [Right Arrow]{CLR_WHITE}  ➔  Increment (+1)", W, "left")
    row_ctrl2 = pad_colored(f" {CLR_YELLOW}[S] / [Down Arrow] / [Left Arrow] {CLR_WHITE}➔  Decrement (-1)", W, "left")
    row_ctrl3 = pad_colored(f" {CLR_YELLOW}[0-9]                             {CLR_WHITE}➔  Set Direct Score", W, "left")
    row_ctrl4 = pad_colored(f" {CLR_YELLOW}[Q] / [ESC]                       {CLR_WHITE}➔  Exit ScoreKeeper", W, "left")

    # Render everything using cyan double-byte borders (│) and perfect alignment
    print(f"{CLR_CYAN}┌──────────────────────────────────────────────────────────┐{CLR_RESET}")
    print(f"{CLR_CYAN}│ {CLR_RESET}{row_title}{CLR_CYAN} │{CLR_RESET}")
    print(f"{CLR_CYAN}├──────────────────────────────────────────────────────────┤{CLR_RESET}")
    print(f"{CLR_CYAN}│ {CLR_RESET}{row_info}{CLR_CYAN} │{CLR_RESET}")
    print(f"{CLR_CYAN}│ {CLR_RESET}{row_net}{CLR_CYAN} │{CLR_RESET}")
    print(f"{CLR_CYAN}├──────────────────────────────────────────────────────────┤{CLR_RESET}")
    print(f"{CLR_CYAN}│ {CLR_RESET}{row_space}{CLR_CYAN} │{CLR_RESET}")
    print(f"{CLR_CYAN}│ {CLR_RESET}{row_score_lbl}{CLR_CYAN} │{CLR_RESET}")
    print(f"{CLR_CYAN}│ {CLR_RESET}{row_space}{CLR_CYAN} │{CLR_RESET}")
    print(f"{CLR_CYAN}│ {CLR_RESET}{row_box_top}{CLR_CYAN} │{CLR_RESET}")
    print(f"{CLR_CYAN}│ {CLR_RESET}{row_box_val}{CLR_CYAN} │{CLR_RESET}")
    print(f"{CLR_CYAN}│ {CLR_RESET}{row_box_bot}{CLR_CYAN} │{CLR_RESET}")
    print(f"{CLR_CYAN}│ {CLR_RESET}{row_space}{CLR_CYAN} │{CLR_RESET}")
    print(f"{CLR_CYAN}├──────────────────────────────────────────────────────────┤{CLR_RESET}")
    print(f"{CLR_CYAN}│ {CLR_RESET}{row_ctrl_lbl}{CLR_CYAN} │{CLR_RESET}")
    print(f"{CLR_CYAN}│ {CLR_RESET}{row_ctrl1}{CLR_CYAN} │{CLR_RESET}")
    print(f"{CLR_CYAN}│ {CLR_RESET}{row_ctrl2}{CLR_CYAN} │{CLR_RESET}")
    print(f"{CLR_CYAN}│ {CLR_RESET}{row_ctrl3}{CLR_CYAN} │{CLR_RESET}")
    print(f"{CLR_CYAN}│ {CLR_RESET}{row_ctrl4}{CLR_CYAN} │{CLR_RESET}")
    print(f"{CLR_CYAN}└──────────────────────────────────────────────────────────┘{CLR_RESET}")
    print(f"{CLR_DIM}Waiting for scorekeeper action...{CLR_RESET}")

def discover_via_subnet_sweep():
    """Sweeps the local /24 subnet concurrently on port 5000 to find the Kindle.
    Highly robust: bypasses Wi-Fi AP isolation and cross-band UDP packet drops."""
    # 1. Resolve local active interface IP
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        local_ip = s.getsockname()[0]
        s.close()
    except Exception:
        return None
        
    prefix = '.'.join(local_ip.split('.')[:3]) + '.'
    print(f"{CLR_CYAN}[SWEEPING]{CLR_WHITE} Scanning local subnet {prefix}1-254 on port {PORT}...{CLR_RESET}")
    
    results = []
    def check_ip(ip):
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.settimeout(0.5) # Increased to 0.5s for slow legacy Kindle 2.4G Wi-Fi
            s.connect((ip, PORT))
            s.close()
            results.append(ip)
        except Exception:
            pass
            
    threads = []
    for i in range(1, 255):
        ip = prefix + str(i)
        if ip == local_ip:
            continue
        t = threading.Thread(target=check_ip, args=(ip,))
        t.start()
        threads.append(t)
        
    # Wait for all sweeps to complete naturally in parallel
    for t in threads:
        t.join()
        
    return results[0] if results else None

def main():
    # Resolve Kindle IP: arg, then try automatic UDP discovery, then try subnet sweep, then fallback
    target_ip = None
    
    if len(sys.argv) > 1 and sys.argv[1]:
        target_ip = sys.argv[1]
    else:
        # Reduce UDP wait to 2 seconds to make the transition to subnet sweep snappy
        print(f"{CLR_CYAN}[SEARCHING]{CLR_WHITE} Listening for Kindle UDP beacons on port 5001 (2s timeout)...{CLR_RESET}")
        try:
            # Set up UDP socket to listen for discovery beacons
            udp_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            udp_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            udp_sock.bind(('', 5001))
            udp_sock.settimeout(2.0) # snappy timeout
            
            data, addr = udp_sock.recvfrom(1024)
            if b"KINDLE_BIGNUM_BEACON" in data:
                target_ip = addr[0]
                print(f"{CLR_GREEN}[DISCOVERED]{CLR_WHITE} Found Kindle via UDP Beacon: {CLR_BOLD}{CLR_YELLOW}{target_ip}{CLR_RESET}")
                time.sleep(1.0)
            udp_sock.close()
        except socket.timeout:
            # UDP timed out (likely Wi-Fi AP isolation or cross-band drop on the Starlink).
            # Fall back to our 100% bulletproof high-speed unicast subnet sweep!
            target_ip = discover_via_subnet_sweep()
            if target_ip:
                print(f"{CLR_GREEN}[DISCOVERED]{CLR_WHITE} Found Kindle via Subnet Scan: {CLR_BOLD}{CLR_YELLOW}{target_ip}{CLR_RESET}")
                time.sleep(1.0)
            else:
                print(f"{CLR_YELLOW}[TIMEOUT]{CLR_WHITE} No Kindle discovered on the local network.{CLR_RESET}")
        except Exception as e:
            print(f"{CLR_RED}[ERROR]{CLR_WHITE} Discovery error: {e}{CLR_RESET}")
            
        if not target_ip:
            # Let the user manually type the IP address so they don't have to restart the app
            print(f"{CLR_CYAN}──────────────────────────────────────────────────────────{CLR_RESET}")
            try:
                user_ip = input(f"{CLR_BOLD}{CLR_WHITE}Enter Kindle IP (or press Enter for default {DEFAULT_KINDLE_IPS[0]}): {CLR_RESET}").strip()
                if user_ip:
                    target_ip = user_ip
            except (KeyboardInterrupt, EOFError):
                print("\nExiting.")
                sys.exit(0)
                
        if not target_ip:
            # Fallback scan list
            for ip in DEFAULT_KINDLE_IPS:
                try:
                    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                    s.settimeout(0.2)
                    s.connect((ip, PORT))
                    s.close()
                    target_ip = ip
                    break
                except Exception:
                    continue
                
    if not target_ip:
        # Ultimate fallback to standard USB-network default if none are reachable
        target_ip = DEFAULT_KINDLE_IPS[0]
        
    score = 0
    last_status = "STANDBY"
    
    # Run initial display draw
    draw_tui(score, target_ip, last_status)
    
    while True:
        key = get_key()
        
        if key in ('q', 'Q', 'ESC'):
            print("\nExiting ScoreKeeper TUI. Good game!")
            break
            
        action_triggered = False
        
        # Parse increment/decrement
        if key in ('w', 'W', 'UP', 'RIGHT', '+'):
            score = (score + 1) % 10
            action_triggered = True
        elif key in ('s', 'S', 'DOWN', 'LEFT', '-'):
            score = (score + 9) % 10
            action_triggered = True
        # Parse direct digits
        elif key in ('0', '1', '2', '3', '4', '5', '6', '7', '8', '9'):
            score = int(key)
            action_triggered = True
            
        if action_triggered:
            # Transmit absolute score over network to maintain perfect synchronization
            success, status = send_command(target_ip, str(score))
            last_status = status
            draw_tui(score, target_ip, last_status)

if __name__ == "__main__":
    main()
