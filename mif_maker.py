import sys
from PIL import Image

# --- Configuration ---
INPUT_IMAGE = "p1_idle_4.png" 
OUTPUT_MIF = "p1_rom.mif"

# Your specific background color to ignore
TRANSPARENT_RGB = (173, 241, 207)

# The 8-bit hex code your Verilog ignores (E3 is standard Magenta)
VERILOG_CHROMA_KEY = "E3" 

def rgb_to_rgb332(r, g, b):
    r_3bit = round((r * 7) / 255)
    g_3bit = round((g * 7) / 255)
    b_2bit = round((b * 3) / 255)
    
    color_8bit = (r_3bit << 5) | (g_3bit << 2) | b_2bit
    return f"{color_8bit:02X}"

def generate_mif():
    try:
        # Load in RGBA mode to keep the transparency data intact!
        img = Image.open(INPUT_IMAGE).convert("RGBA")
    except FileNotFoundError:
        print(f"Error: Could not find '{INPUT_IMAGE}'. Make sure it's in the same folder.")
        sys.exit(1)

    width, height = img.size
    total_pixels = width * height
    
    print(f"Loaded '{INPUT_IMAGE}' ({width}x{height}).")
    print(f"Generating {total_pixels} memory blocks for Quartus...")

    with open(OUTPUT_MIF, "w") as f:
        f.write(f"DEPTH = {total_pixels};\n")
        f.write("WIDTH = 8;\n")
        f.write("ADDRESS_RADIX = UNS;\n")  
        f.write("DATA_RADIX = HEX;\n\n")   
        f.write("CONTENT BEGIN\n")

        address = 0
        for y in range(height):
            for x in range(width):
                # Now we unpack 4 values: Red, Green, Blue, and Alpha (Transparency)
                r, g, b, a = img.getpixel((x, y))
                
                # --- THE DUAL INTERCEPTOR ---
                # 1. If the pixel is mostly transparent (Alpha < 128)
                if a < 128:
                    hex_color = VERILOG_CHROMA_KEY
                    
                # 2. Or if the pixel exactly matches your solid green background
                elif (r, g, b) == TRANSPARENT_RGB:
                    hex_color = VERILOG_CHROMA_KEY
                    
                # 3. Otherwise, just draw the normal color
                else:
                    hex_color = rgb_to_rgb332(r, g, b)
                # ----------------------------
                
                f.write(f"\t{address} : {hex_color};\n")
                address += 1
                
        f.write("END;\n")
        
    print(f"Success! Saved memory initialization file to '{OUTPUT_MIF}'")

if __name__ == "__main__":
    generate_mif()