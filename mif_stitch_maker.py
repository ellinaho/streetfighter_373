import sys
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

OUTPUT_MIF  = "p1_punch_anim.mif"
CHROMA_KEY_HEX = "E3"
# =================================================================

def rgb_to_rgb332(r, g, b):
    # Standard integer division (The Floor Fix)
    r_3bit = (r * 7) // 255
    g_3bit = (g * 7) // 255
    b_2bit = (b * 3) // 255
    return f"{(r_3bit << 5) | (g_3bit << 2) | b_2bit:02X}"

def generate_dynamic_mif():
    print(f"--- MIF GENERATOR (VARIABLE SIZE STITCHER + WHITE PIXEL FIX) ---")
    
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
                
                is_transparent = (a < 128)
                is_magenta_halo = (r > 100) and (b > 100) and (g < 90)
                
                # THE WHITE PIXEL SAVIOR
                # Now checks for low green so it doesn't accidentally eat white (255, 255, 255)!
                is_pure_magenta = (r > 240) and (b > 240) and (g < 50)

                if is_transparent or is_magenta_halo or is_pure_magenta:
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
    
    # Generate the Verilog LUT
    print("\n" + "="*50)
    print("COPY THIS LOOKUP TABLE INTO YOUR VERILOG (vga_pixel.v)")
    print("="*50)
    print("reg [16:0] frame_offset;")
    print("reg [9:0] current_w, current_h;")
    print("always @(*) begin")
    print("    case(p1_frame)")
    for data in frame_data:
        print(f"        {data['frame']}: begin frame_offset = {data['offset']}; current_w = {data['width']}; current_h = {data['height']}; end")
    print("        default: begin frame_offset = 0; current_w = 64; current_h = 53; end")
    print("    endcase")
    print("end\n")

if __name__ == "__main__":
    generate_dynamic_mif()