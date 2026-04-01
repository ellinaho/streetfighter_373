module top(
    input CLOCK_50,

    output VGA_HS,
    output VGA_VS,
    output VGA_BLANK_N,
    output VGA_SYNC_N,
    output VGA_CLK,
    output [7:0] VGA_R,
    output [7:0] VGA_G,
    output [7:0] VGA_B
);

//ROM WIRES
    wire [14:0] bg_rom_addr;
    wire [7:0] bg_rom_data;

//HARDWARE ROM
    bg_sprite_rom background_memory (.address(bg_rom_addr), .clock(CLOCK_50), .q(bg_rom_data));

//call graphics, TODO: ensure inputs are all right
    graphics my_graphics (
        .CLOCK_50   (CLOCK_50),
        .bg_rom_addr(bg_rom_addr),
        .bg_rom_data(bg_rom_data),
        
        .VGA_HS     (VGA_HS),
        .VGA_VS     (VGA_VS),
        .VGA_BLANK_N(VGA_BLANK_N),
        .VGA_SYNC_N (VGA_SYNC_N),
        .VGA_CLK    (VGA_CLK),
        .VGA_R      (VGA_R),
        .VGA_G      (VGA_G),
        .VGA_B      (VGA_B)
    );

endmodule