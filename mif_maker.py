import sys
import colorsys
from PIL import Image

# =================================================================
# CONFIGURATION
# =================================================================
INPUT_IMAGE = "p2 sprite.png"  
OUTPUT_MIF  = "p2.mif"

# The 8-bit hex code your Verilog ignores (E3 is pure RGB332 Magenta)
CHROMA_KEY_HEX = "E3"

# --- THE HSV HALO SETTINGS (Tightened to protect red/pink clothes) ---
HUE_MIN = 0.80 
HUE_MAX = 0.88 
MIN_SATURATION = 0.50 
MIN_BRIGHTNESS = 0.50 
# =================================================================

def rgb_to_rgb332(r, g, b):
    r_3bit = round((r * 7) / 255)
    g_3bit = round((g * 7) / 255)
    
    # THE BLUE NOISE KILLER
    # If the blue value is low (just a shadow), crush it to 0. 
    # This mathematically prevents 2-bit blue from rounding up to 33% intensity
    if b < 50:
        b_2bit = 0
    else:
        b_2bit = round((b * 3) / 255)
        
    return f"{(r_3bit << 5) | (g_3bit << 2) | b_2bit:02X}"

def generate_mif():
    try:
        img = Image.open(INPUT_IMAGE).convert("RGBA")
    except FileNotFoundError:
        print(f"Error: Could not find '{INPUT_IMAGE}'.")
        sys.exit(1)

    width, height = img.size
    total_pixels = width * height
    
    print(f"--- MIF GENERATOR (HSV & NOISE FILTER) ---")
    print(f"Image: {INPUT_IMAGE} ({width}x{height})")

    with open(OUTPUT_MIF, "w") as f:
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
                
                # 2. Is it the Magenta Background? (Using the tightened settings)
                is_magenta_hue = (HUE_MIN < h < HUE_MAX)
                is_colorful = (s > MIN_SATURATION)
                is_bright = (v > MIN_BRIGHTNESS)

                if is_transparent_png or (is_magenta_hue and is_colorful and is_bright):
                    hex_color = CHROMA_KEY_HEX
                    removed_count += 1
                else:
                    hex_color = rgb_to_rgb332(r, g, b)
                
                f.write(f"\t{address} : {hex_color};\n")
                address += 1
                
        f.write("END;\n")
        
    print(f"Success! Purged {removed_count} background pixels.")
    print(f"File saved as: {OUTPUT_MIF}")

if __name__ == "__main__":
    generate_mif()