import sys
from PIL import Image

# =================================================================
# CONFIGURATION
# =================================================================
INPUT_IMAGE = "p1_idle_ok.png"  
OUTPUT_MIF  = "p1_rom.mif"

# The background color is now Pure Magenta
TARGET_BG_RGB = (255, 0, 255)

# THE LEVEL-UP: 
# 150 will aggressively kill anything remotely pink or purple. 
# If it starts eating your character's skin/clothes, dial it back to 100.
# If you STILL see purple fringes, crank it up to 200.
TOLERANCE = 150 

# The 8-bit hex code your Verilog ignores (E3 is pure RGB332 Magenta)
CHROMA_KEY_HEX = "E3"

# =================================================================

def rgb_to_rgb332(r, g, b):
    """
    Converts 24-bit RGB to 8-bit RGB332.
    R: 3 bits, G: 3 bits, B: 2 bits
    """
    r_3bit = round((r * 7) / 255)
    g_3bit = round((g * 7) / 255)
    b_2bit = round((b * 3) / 255)
    
    color_8bit = (r_3bit << 5) | (g_3bit << 2) | b_2bit
    return f"{color_8bit:02X}"

def generate_mif():
    try:
        img = Image.open(INPUT_IMAGE).convert("RGBA")
    except FileNotFoundError:
        print(f"Error: Could not find '{INPUT_IMAGE}'.")
        sys.exit(1)

    width, height = img.size
    total_pixels = width * height
    
    print(f"--- MIF GENERATOR (MAX MAGENTA DELETION) ---")
    print(f"Image: {INPUT_IMAGE} ({width}x{height})")
    print(f"Total Depth: {total_pixels} pixels")
    print(f"Tolerance: {TOLERANCE}")

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
                
                # Manhattan Distance from Pure Magenta (255, 0, 255)
                # The closer this is to 0, the more "pure magenta" the pixel is.
                # A high tolerance catches the muddy purples from anti-aliasing.
                color_diff = (255 - r) + g + (255 - b)

                # DETERMINATION LOGIC:
                # 1. Is it transparent in the PNG file?
                # 2. Is the color difference less than our massive tolerance?
                
                is_transparent_png = (a < 128)
                is_remotely_magenta = (color_diff < TOLERANCE)

                if is_transparent_png or is_remotely_magenta:
                    hex_color = CHROMA_KEY_HEX
                    removed_count += 1
                else:
                    # It's a real pixel! Convert to RGB332.
                    hex_color = rgb_to_rgb332(r, g, b)
                
                f.write(f"\t{address} : {hex_color};\n")
                address += 1
                
        f.write("END;\n")
        
    print(f"Success! Purged {removed_count} background/halo pixels.")
    print(f"File saved as: {OUTPUT_MIF}")

if __name__ == "__main__":
    generate_mif()