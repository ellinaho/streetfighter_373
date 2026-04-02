import sys
from PIL import Image

# =================================================================
# CONFIGURATION
# =================================================================
INPUT_IMAGE = "p1_idle_4.png"  # Your sprite sheet (e.g., 64x212 for 4 frames)
OUTPUT_MIF  = "p1_rom.mif"

# The light green background color you want to turn invisible (#ADF1CF)
TARGET_BG_RGB = (173, 241, 207)

# How "fuzzy" the match is. If you still see green edges, increase this (try 40-50).
# If the character's skin/clothes disappear, decrease this (try 15-20).
TOLERANCE = 30 

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
        # We use RGBA to detect actual transparency if it exists in the PNG
        img = Image.open(INPUT_IMAGE).convert("RGBA")
    except FileNotFoundError:
        print(f"Error: Could not find '{INPUT_IMAGE}'.")
        sys.exit(1)

    width, height = img.size
    total_pixels = width * height
    
    print(f"--- MIF GENERATOR ---")
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

        # Scan through the image
        for y in range(height):
            for x in range(width):
                r, g, b, a = img.getpixel((x, y))
                
                # Calculate "Color Distance" from our target green
                # (Manhattan distance is faster and works well for this)
                color_diff = abs(r - TARGET_BG_RGB[0]) + \
                             abs(g - TARGET_BG_RGB[1]) + \
                             abs(b - TARGET_BG_RGB[2])

                # DETERMINATION LOGIC:
                # 1. Is it transparent in the PNG file?
                # 2. Is it "close enough" to our target background green?
                # 3. Is it a stray pure Magenta pixel (255, 0, 255)?
                
                is_transparent_png = (a < 128)
                is_fuzzy_bg_match  = (color_diff < TOLERANCE)
                is_pure_magenta    = (r > 240 and g < 10 and b > 240)

                if is_transparent_png or is_fuzzy_bg_match or is_pure_magenta:
                    hex_color = CHROMA_KEY_HEX
                    removed_count += 1
                else:
                    # It's a real pixel! Convert to RGB332.
                    hex_color = rgb_to_rgb332(r, g, b)
                
                # Write to MIF: [Address] : [HexData];
                f.write(f"\t{address} : {hex_color};\n")
                address += 1
                
        f.write("END;\n")
        
    print(f"Success! Cleaned up {removed_count} background pixels.")
    print(f"File saved as: {OUTPUT_MIF}")

if __name__ == "__main__":
    generate_mif()