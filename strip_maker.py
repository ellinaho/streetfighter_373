from PIL import Image
import sys

def convert_to_vertical_strip(input_file, output_file, read_right_to_left=False):
    # --- FPGA Canvas Settings ---
    SPRITE_W = 188
    SPRITE_H = 156
    ANCHOR_X = 94   # Horizontal Center
    # We want row (anchor_y - 1) to be the bottom of our 156px box
    # So we set the target for the feet, not the guide row.
    FEET_Y   = 155  
    CYAN     = (0, 255, 255) 

    print(f"Loading '{input_file}'...")
    img = Image.open(input_file).convert("RGBA")
    pixels = img.load()

    # 1. Find the neon cyan anchor pixels
    anchors = []
    for y in range(img.height):
        for x in range(img.width):
            if pixels[x, y][:3] == CYAN:
                anchors.append((x, y))

    print(f"Found {len(anchors)} cyan anchor pixels.")
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
        
        # --- THE FIX ---
        # Instead of putting anchor_y at 155, we put anchor_y at 156.
        # This makes row (anchor_y - 1) land on 155.
        paste_x = ANCHOR_X - anchor_x
        paste_y = (FEET_Y + 1) - anchor_y # Shifted up by 1
        
        # Paste the original image
        # PIL will automatically clip anything that falls outside (0, 0, 188, 156)
        frame.paste(img, (paste_x, paste_y))
        
        # Calculate vertical position on the strip
        strip_y_offset = frame_index * SPRITE_H
        final_strip.paste(frame, (0, strip_y_offset))

    # Save
    final_strip.save(output_file)
    print(f"Success! Aligned strip saved to '{output_file}'. Guide row was clipped.")

# --- Execution ---
convert_to_vertical_strip("p1walkh.png", "p1walkv.png", read_right_to_left=False)