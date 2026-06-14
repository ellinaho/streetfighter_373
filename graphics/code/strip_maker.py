from PIL import Image
import sys

def convert_to_vertical_strip(input_file, output_file, read_right_to_left=False):
    # fpga canvas
    SPRITE_W = 188
    SPRITE_H = 156
    ANCHOR_X = 94   
    FEET_Y   = 155  
    
    CYAN = (0, 255, 255) 
    TARGET_BG = (173, 241, 207)   
    NEON_MAGENTA = (255, 0, 255, 255) 

    print(f"Loading '{input_file}'...")
    img = Image.open(input_file).convert("RGBA")
    pixels = img.load()

    # find neon cyan pixel
    anchors = []
    replaced_count = 0
    
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = pixels[x, y]
            
            # check if cyan dot
            if (r, g, b) == CYAN:
                anchors.append((x, y))
            
            # if background, replace
            elif (r, g, b) == TARGET_BG:
                pixels[x, y] = NEON_MAGENTA
                replaced_count += 1

    print(f"Found {len(anchors)} cyan anchor pixels.")
    print(f"Replaced {replaced_count} background pixels with Neon Magenta.")
    
    if len(anchors) == 0:
        print("Error: Could not find any (0, 255, 255) pixels.")
        return

    # sort anchor
    anchors.sort(key=lambda p: p[0])

    # if right to left
    if read_right_to_left:
        anchors.reverse()
        print("Reversing frame order.")

    # create strip
    final_strip = Image.new("RGBA", (SPRITE_W, SPRITE_H * len(anchors)), (0, 0, 0, 0))

    # crop + align
    for frame_index, (anchor_x, anchor_y) in enumerate(anchors):

        frame = Image.new("RGBA", (SPRITE_W, SPRITE_H), (0, 0, 0, 0))
        
        paste_x = ANCHOR_X - anchor_x
        paste_y = (FEET_Y + 1) - anchor_y 
        
        frame.paste(img, (paste_x, paste_y))

        strip_y_offset = frame_index * SPRITE_H
        final_strip.paste(frame, (0, strip_y_offset))

    final_strip.save(output_file)
    print(f"Success! Aligned strip saved to '{output_file}'. Guide row was clipped.")

convert_to_vertical_strip("test.png", "testv.png", read_right_to_left=False)