#!/usr/bin/env python3
import os
import sys

def main():
    if len(sys.argv) < 2:
        print("Usage: generate_images.py <output_directory>")
        sys.exit(1)
        
    output_dir = sys.argv[1]
    os.makedirs(output_dir, exist_ok=True)
    
    # We must try importing Pillow inside to handle environments gracefully
    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError:
        print("Pillow is not installed in the active environment.")
        sys.exit(1)
        
    # Standard macOS sans-serif fonts
    font_paths = [
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/System/Library/Fonts/HelveticaNeue.ttc",
    ]
    
    font_path = None
    for fp in font_paths:
        if os.path.exists(fp):
            font_path = fp
            break
            
    if not font_path:
        print("Error: No standard macOS fonts found.")
        sys.exit(1)
        
    width, height = 600, 800
    
    for digit in range(10):
        text = str(digit)
        
        # Create a grayscale image (mode L: 8-bit pixels, black and white)
        # Background is white (255)
        img = Image.new("L", (width, height), color=255)
        draw = ImageDraw.Draw(img)
        
        # Find the maximum font size that fits within the boundaries (600x800 screen)
        # Margin is 10px on all sides, meaning max width is 580 and max height is 780
        font_size = 1200
        font = None
        while font_size > 50:
            font = ImageFont.truetype(font_path, font_size)
            # draw.textbbox returns (left, top, right, bottom)
            left, top, right, bottom = draw.textbbox((0, 0), text, font=font)
            w = right - left
            h = bottom - top
            # Check if fits within 580x780 area (leaving 10px margins)
            if w <= 580 and h <= 780:
                break
            font_size -= 5
            
        # Draw the text perfectly centered
        left, top, right, bottom = draw.textbbox((0, 0), text, font=font)
        w = right - left
        h = bottom - top
        
        x = (width - w) // 2 - left
        y = (height - h) // 2 - top
        
        # Fill is black (0)
        draw.text((x, y), text, font=font, fill=0)
        
        # Save as PNG
        out_path = os.path.join(output_dir, f"{digit}.png")
        img.save(out_path, format="PNG")
        print(f"Generated {out_path} (font size: {font_size})")

if __name__ == "__main__":
    main()
