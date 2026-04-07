import sys
import os

# =================================================================
# CONFIGURATION
# List the exact names of the .mif files you want to combine.
# The order here determines their placement in the final memory block!
# =================================================================
MIF_FILES = [
    "p1pfp.mif",
    "p2pfp.mif",
    "title.mif",
    "ko.mif",
    "instr.mif"
]

OUTPUT_MIF = "master_rom.mif"
# =================================================================

def merge_mif_files():
    print("--- MIF MASTER ARRAY MERGER ---")
    
    all_hex_data = []
    base_addresses = {}
    current_offset = 0

    # 1. Extract data from all files
    for filename in MIF_FILES:
        if not os.path.exists(filename):
            print(f"Error: Could not find '{filename}'. Please check the name.")
            sys.exit(1)
            
        print(f"Reading '{filename}'...")
        base_addresses[filename] = current_offset
        
        with open(filename, 'r') as f:
            lines = f.readlines()
            
        in_content = False
        file_pixel_count = 0
        
        for line in lines:
            line = line.strip()
            
            # Look for the start and end of the actual memory array
            if line == "CONTENT BEGIN":
                in_content = True
                continue
            if line == "END;":
                in_content = False
                continue
                
            # If we are inside the array, extract the hex value
            if in_content and ":" in line:
                # Format is usually "address : data;"
                parts = line.split(":")
                if len(parts) == 2:
                    hex_value = parts[1].strip().replace(";", "")
                    all_hex_data.append(hex_value)
                    file_pixel_count += 1
                    current_offset += 1
                    
        print(f"  -> Extracted {file_pixel_count} pixels. (Starts at offset {base_addresses[filename]})")

    # 2. Write the new combined Master MIF
    total_depth = len(all_hex_data)
    print(f"\nWriting {total_depth} total pixels to '{OUTPUT_MIF}'...")
    
    with open(OUTPUT_MIF, "w") as f:
        f.write(f"DEPTH = {total_depth};\n")
        f.write("WIDTH = 8;\n")
        f.write("ADDRESS_RADIX = UNS;\n")
        f.write("DATA_RADIX = HEX;\n\n")
        f.write("CONTENT BEGIN\n")
        
        for new_address, hex_val in enumerate(all_hex_data):
            f.write(f"\t{new_address} : {hex_val};\n")
            
        f.write("END;\n")

    print("\nSuccess! Combination complete.")
    
    # 3. Print the Verilog parameters for easy copy-pasting
    print("\n" + "="*50)
    print("COPY THESE BASE ADDRESSES INTO YOUR VERILOG")
    print("="*50)
    for filename, offset in base_addresses.items():
        # Clean up the filename to make a neat Verilog parameter name (e.g., p1_idle.mif -> P1_IDLE_BASE)
        clean_name = filename.split('.')[0].upper()
        print(f"parameter {clean_name}_BASE = 17'd{offset};")
    print("="*50 + "\n")

if __name__ == "__main__":
    merge_mif_files()