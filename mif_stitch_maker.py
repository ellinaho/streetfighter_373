import sys
import colorsys
from PIL import Image

# =================================================================
# CONFIGURATION
# List your frames in order. THEY CAN BE ANY SIZE!
# =================================================================
FRAME_SEQUENCE = [
    "p1pfp.png", 
    "p2pfp.png", 
    "title.png",
    "ko.png",
    "instr.png"
]  
OUTPUT_MIF  = "element.mif"

# The 8-bit hex code your Verilog ignores (E3 is pure RGB332 Magenta)
CHROMA_KEY_HEX = "E3"

# --- THE HSV HALO SETTINGS (YOUR EXACT SETTINGS) ---
HUE_MIN = 0.72 
HUE_MAX = 0.95 
MIN_SATURATION = 0.4 
MIN_BRIGHTNESS = 0.5
# =================================================================

def rgb_to_rgb332(r, g, b):
    # YOUR EXACT MATH AND SHADOW FIX
    r_3bit = round((r * 7) / 255)
    g_3bit = round((g * 7) / 255)
    b_2bit = round((b * 3) / 255)
    
    if b < 80:
        b_2bit = 0
    
    return f"{(r_3bit << 5) | (g_3bit << 2) | b_2bit:02X}"

def generate_stitched_mif():
    print(f"--- MIF GENERATOR (YOUR HSV LOGIC + VARIABLE SIZE STITCHER) ---")
    
    all_hex_pixels = []
    frame_data = [] # Stores (start_address, width, height)
    removed_count = 0
    current_address = 0

    for index, filename in enumerate(FRAME_SEQUENCE):
        try:
            img = Image.open(filename).convert("RGBA")
        except FileNotFoundError:
            print(f"Error: Could not find '{filename}'. Halting.")
            sys.exit(1)

        width, height = img.size
        print(f"Packing Frame {index}: {filename} ({width}x{height}) -> Starts at {current_address}")
        
        # Record the exact offset and dimensions for Verilog
        frame_data.append({
            "frame": index,
            "offset": current_address,
            "width": width,
            "height": height
        })

        for y in range(height):
            for x in range(width):
                r, g, b, a = img.getpixel((x, y))
                
                # --- YOUR EXACT PIXEL FILTERING LOGIC ---
                h, s, v = colorsys.rgb_to_hsv(r/255.0, g/255.0, b/255.0)

                is_transparent_png = (a < 128)
                is_magenta_hue = (HUE_MIN < h < HUE_MAX)
                is_colorful = (s > MIN_SATURATION)
                is_bright = (v > MIN_BRIGHTNESS)

                if is_transparent_png or (is_magenta_hue and is_colorful and is_bright):
                    all_hex_pixels.append(CHROMA_KEY_HEX)
                    removed_count += 1
                else:
                    all_hex_pixels.append(rgb_to_rgb332(r, g, b))
                
                current_address += 1

    total_pixels = len(all_hex_pixels)
    
    with open(OUTPUT_MIF, "w") as f:
        f.write(f"DEPTH = {total_pixels};\n")
        f.write("WIDTH = 8;\n")
        f.write("ADDRESS_RADIX = UNS;\n")
        f.write("DATA_RADIX = HEX;\n\n")
        f.write("CONTENT BEGIN\n")

        for addr, hex_color in enumerate(all_hex_pixels):
            f.write(f"\t{addr} : {hex_color};\n")
                
        f.write("END;\n")
        
    print(f"\nSuccess! Stitched into {OUTPUT_MIF} ({total_pixels} pixels).")
    print(f"Purged {removed_count} magenta/purple pixels using your custom HSV filter.")
    
    # Generate the Verilog LUT
    print("\n" + "="*50)
    print("COPY THIS LOOKUP TABLE INTO YOUR VERILOG")
    print("="*50)
    print("reg [16:0] frame_offset;")
    print("reg [9:0] current_w, current_h;")
    print("always @(*) begin")
    print("    case(p2_frame) // Change to p1_frame if needed")
    for data in frame_data:
        print(f"        {data['frame']}: begin frame_offset = {data['offset']}; current_w = {data['width']}; current_h = {data['height']}; end")
    print("        default: begin frame_offset = 0; current_w = 64; current_h = 53; end")
    print("    endcase")
    print("end\n")

if __name__ == "__main__":
    generate_stitched_mif()