from PIL import Image

def convert_to_vertical_strip(input_file, output_file, read_right_to_left=False):
    # --- FPGA Canvas Settings ---
    SPRITE_W = 188
    SPRITE_H = 156
    ANCHOR_X = 94  # Center of the 64px width
    ANCHOR_Y = 155  # Bottom edge of the 53px height
    MAGENTA = (255, 0, 255) # Pure neon magenta

    # Load the original image and force it to have an Alpha (transparency) channel
    print(f"Loading '{input_file}'...")
    img = Image.open(input_file).convert("RGBA")
    pixels = img.load()

    # 1. Scan the entire image to find the neon magenta anchor pixels
    anchors = []
    for y in range(img.height):
        for x in range(img.width):
            # Check the RGB values (ignoring the Alpha transparency value)
            if pixels[x, y][:3] == MAGENTA:
                anchors.append((x, y))

    print(f"Found {len(anchors)} magenta anchor pixels.")
    if len(anchors) == 0:
        print("Error: Could not find any (255, 0, 255) pixels. Make sure it is pure magenta!")
        return

    # 2. Sort the anchors from left to right based on their X coordinate
    anchors.sort(key=lambda p: p[0])

    # 3. Handle the "Moonwalk" bug (Manga-style right-to-left sheets)
    if read_right_to_left:
        anchors.reverse()
        print("Reversing frame order (Right-to-Left mode active).")

    # 4. Create the massive vertical blank canvas for the final strip
    # Width = 64, Height = 53 * number of frames
    final_strip = Image.new("RGBA", (SPRITE_W, SPRITE_H * len(anchors)), (0, 0, 0, 0))

    # 5. Crop and align each frame
    for frame_index, (anchor_x, anchor_y) in enumerate(anchors):
        
        # Create a blank 64x53 frame
        frame = Image.new("RGBA", (SPRITE_W, SPRITE_H), (0, 0, 0, 0))
        
        # Calculate the exact offset to paste the original image so that 
        # the magenta pixel lands perfectly on (32, 52)
        paste_x = ANCHOR_X - anchor_x
        paste_y = ANCHOR_Y - anchor_y
        
        # Paste the original image onto the 64x53 frame
        frame.paste(img, (paste_x, paste_y))
        
        # Erase the magenta pixel by making it 100% transparent
        frame_pixels = frame.load()
        frame_pixels[ANCHOR_X, ANCHOR_Y] = (0, 0, 0, 0)
        
        # Calculate where this frame belongs on the final vertical strip
        strip_y_offset = frame_index * SPRITE_H
        
        # Paste the perfected frame into the final strip
        final_strip.paste(frame, (0, strip_y_offset))

    # Save the ready-to-use file
    final_strip.save(output_file)
    print(f"Success! Saved perfectly aligned vertical strip to '{output_file}'.")


# --- RUN THE SCRIPT HERE ---

# If your downloaded sheet reads normally (Left to Right):
convert_to_vertical_strip("p1_idle_h_og.png", "p1_idle_v_og.png", read_right_to_left=False)

# If your downloaded sheet reads backwards (Right to Left):
# convert_to_vertical_strip("your_raw_sheet.png", "player_aligned.png", read_right_to_left=True)