import sys
import colorsys
from PIL import Image

# =================================================================
# CONFIGURATION
# =================================================================
INPUT_IMAGE = "p1_idle_ok.png"  
OUTPUT_MIF  = "p1_rom.mif"

# The 8-bit hex code your Verilog ignores (E3 is pure RGB332 Magenta)
CHROMA_KEY_HEX = "E3"

# --- THE RUTHLESS HSV HALO SETTINGS ---
# Hue is measured from 0.0 to 1.0. 
# Pure Magenta is ~0.83. This range covers deep muddy purples to bright pinks.
HUE_MIN = 0.72 
HUE_MAX = 0.95 

# We set these incredibly low. If a pixel has even 5% color and 2% brightness, 
# and that color happens to be purple/magenta, it gets destroyed.
MIN_SATURATION = 0.05 
MIN_BRIGHTNESS = 0.02 
# =================================================================

def rgb_to_rgb332(r, g, b):
    """Converts 24-bit RGB to 8-bit RGB332."""
    r_3bit = round((r * 7) / 255)
    g_3bit = round((g * 7) / 255)
    b_2bit = round((b * 3) / 255)
    return f"{(r_3bit << 5) | (g_3bit << 2) | b_2bit:02X}"

def generate_mif():
    try:
        img = Image.open(INPUT_IMAGE).convert("RGBA")
    except FileNotFoundError:
        print(f"Error: Could not find '{INPUT_IMAGE}'. Make sure it is in the same folder.")
        sys.exit(1)

    width, height = img.size
    total_pixels = width * height
    
    print(f"--- MIF GENERATOR (RUTHLESS HALO KILLER) ---")
    print(f"Image: {INPUT_IMAGE} ({width}x{height})")

    with open(OUTPUT_MIF, "w") as f:
        # Quartus Header
        f.write(f"DEPTH = {total_pixels};\n")
        f.write("WIDTH = 8;\n")
        f.write("ADDRESS_RADIX = UNS;\n")
        f.write("DATA_RADIX = HEX;\n\n")
        f.write("CONTENT BEGIN\n")

        address = 0
        removed_count = 0

        for y in range(height):
            for x in range(width):
                r, g, b, a = img.getpixel((x, y))
                
                # Convert RGB to HSV (returns values between 0.0 and 1.0)
                h, s, v = colorsys.rgb_to_hsv(r/255.0, g/255.0, b/255.0)

                # 1. Is it a PNG transparent pixel?
                is_transparent_png = (a < 128)
                
                # 2. Is it in the Purple/Magenta hue range?
                is_magenta_hue = (HUE_MIN < h < HUE_MAX)
                
                # 3. Is it slightly colorful and slightly bright? 
                # (This prevents pure white, pure black, or true greys from being deleted)
                is_colorful = (s > MIN_SATURATION)
                is_bright = (v > MIN_BRIGHTNESS)

                # THE RUTHLESS KILL: If it's transparent OR (it's purple AND not absolute pure black/grey)
                if is_transparent_png or (is_magenta_hue and is_colorful and is_bright):
                    hex_color = CHROMA_KEY_HEX
                    removed_count += 1
                else:
                    hex_color = rgb_to_rgb332(r, g, b)
                
                f.write(f"\t{address} : {hex_color};\n")
                address += 1
                
        f.write("END;\n")
        
    print(f"Success! Purged {removed_count} magenta/purple halo pixels.")
    print(f"File saved as: {OUTPUT_MIF}")

if __name__ == "__main__":
    generate_mif()