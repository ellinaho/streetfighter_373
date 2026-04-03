from PIL import Image
import sys

def convert_to_vertical_strip(input_file, output_file, read_right_to_left=False):
    # --- FPGA Canvas Settings ---
    SPRITE_W = 188
    SPRITE_H = 156
    ANCHOR_X = 94   # Horizontal Center
    FEET_Y   = 155  
    
    # --- Color Definitions ---
    CYAN = (0, 255, 255) 
    TARGET_BG = (173, 241, 207)       # Hex: ADF1CF
    NEON_MAGENTA = (255, 0, 255, 255) # Hex: FF00FF (with 255 for full alpha)

    print(f"Loading '{input_file}'...")
    img = Image.open(input_file).convert("RGBA")
    pixels = img.load()

    # 1. Find the neon cyan anchors AND replace the background color
    anchors = []
    replaced_count = 0
    
    for y in range(img.height):
        for x in range(img.width):
            # Extract current pixel colors (ignoring alpha for the check)
            r, g, b, a = pixels[x, y]
            
            # Check if it's the anchor dot
            if (r, g, b) == CYAN:
                anchors.append((x, y))
            
            # Check if it's the background color, and replace it instantly
            elif (r, g, b) == TARGET_BG:
                pixels[x, y] = NEON_MAGENTA
                replaced_count += 1

    print(f"Found {len(anchors)} cyan anchor pixels.")
    print(f"Replaced {replaced_count} background pixels with Neon Magenta.")
    
    if len(anchors) == 0:
        print("Error: Could not find any (0, 255, 255) pixels.")
        return

    # 2. Sort anchors (Left-to-Right)
    anchors.sort(key=lambda p: p[0])

    # 3. Handle Right-to-Left sheets
    if read_right_to_left:
        anchors.reverse()
        print("Reversing frame order.")

    # 4. Create the final vertical strip
    final_strip = Image.new("RGBA", (SPRITE_W, SPRITE_H * len(anchors)), (0, 0, 0, 0))

    # 5. Crop and align
    for frame_index, (anchor_x, anchor_y) in enumerate(anchors):
        
        # Create a blank frame
        frame = Image.new("RGBA", (SPRITE_W, SPRITE_H), (0, 0, 0, 0))
        
        paste_x = ANCHOR_X - anchor_x
        paste_y = (FEET_Y + 1) - anchor_y # Shifted up by 1
        
        # Paste the modified image
        frame.paste(img, (paste_x, paste_y))
        
        # Calculate vertical position on the strip
        strip_y_offset = frame_index * SPRITE_H
        final_strip.paste(frame, (0, strip_y_offset))

    # Save
    final_strip.save(output_file)
    print(f"Success! Aligned strip saved to '{output_file}'. Guide row was clipped.")

# --- Execution ---
convert_to_vertical_strip("3.png", "3v.png", read_right_to_left=False)