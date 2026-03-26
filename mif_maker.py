import sys
from PIL import Image

# --- Configuration ---
# Change these variables to match your file names!
INPUT_IMAGE = "p2.png" 
OUTPUT_MIF = "p2_rom.mif"

# Pure Magenta for hardware transparency
TRANSPARENT_COLOR = (255, 0, 255) 

def rgb_to_rgb332(r, g, b):
    """
    Converts standard 24-bit RGB into 8-bit RGB332.
    Format: [R2 R1 R0 G2 G1 G0 B1 B0]
    """
    # If the pixel is pure magenta, force it to our transparent hex code (FF)
    if (r, g, b) == TRANSPARENT_COLOR:
        return "FF"
        
    # Bitwise shift to grab the top bits of each color channel
    r_3bit = (r >> 5) & 0x07
    g_3bit = (g >> 5) & 0x07
    b_2bit = (b >> 6) & 0x03
    
    # Combine them into a single 8-bit byte
    color_8bit = (r_3bit << 5) | (g_3bit << 2) | b_2bit
    
    # Return as a 2-character hexadecimal string (e.g., "A4", "00", "FF")
    return f"{color_8bit:02X}"

def generate_mif():
    try:
        # Load the image and force it into standard RGB mode (stripping alpha channels)
        img = Image.open(INPUT_IMAGE).convert("RGB")
    except FileNotFoundError:
        print(f"Error: Could not find '{INPUT_IMAGE}'. Make sure it's in the same folder.")
        sys.exit(1)

    width, height = img.size
    total_pixels = width * height
    
    print(f"Loaded '{INPUT_IMAGE}' ({width}x{height}).")
    print(f"Generating {total_pixels} memory blocks for Quartus...")

    # Write the .mif file
    with open(OUTPUT_MIF, "w") as f:
        # --- Quartus MIF Header ---
        f.write(f"DEPTH = {total_pixels};\n")
        f.write("WIDTH = 8;\n")
        f.write("ADDRESS_RADIX = UNS;\n")  # Memory addresses are unsigned integers
        f.write("DATA_RADIX = HEX;\n\n")   # Pixel color data is in hex
        f.write("CONTENT BEGIN\n")

        # --- Pixel Data ---
        address = 0
        for y in range(height):
            for x in range(width):
                r, g, b = img.getpixel((x, y))
                hex_color = rgb_to_rgb332(r, g, b)
                
                # Format: [Address] : [Data];
                f.write(f"\t{address} : {hex_color};\n")
                address += 1
                
        f.write("END;\n")
        
    print(f"Success! Saved memory initialization file to '{OUTPUT_MIF}'")

if __name__ == "__main__":
    generate_mif()