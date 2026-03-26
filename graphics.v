module graphics(
    input CLOCK_50, //50MHz?

    //inputs from game logic
    input [9:0] p1_x, 
    input [9:0] p1_y,
    input [3:0] p1_state,       // 0=Idle, 1=Walk, 2=Jump, 3=Punch, 4=Kick
    input [2:0] p1_frame,       // Needed for animation!
    input [7:0] p1_hp,          // Health points (0 to 50)


    input [9:0] p2_x,
    input [9:0] p2_y,
    input [3:0] p2_state,
    input [2:0] p2_frame,
    input [7:0] p2_hp,
    
    // =========================================================================
    // 2. ROM CONNECTIONS (Talking to the memory chips)
    // =========================================================================
    // We send these addresses OUT to the ROM IP Cores

    //Talk to memory (this is where we store pixel color data)
    output reg [16:0] p1_rom_addr, 
    output reg [16:0] p2_rom_addr,
    
    // The ROM IP Cores send the 8-bit color of that specific pixel BACK to us
    input [7:0] p1_rom_data, 
    input [7:0] p2_rom_data,
    
    output VGA_HS, //horizontal sync
    output VGA_VS, //vertical sync
    output VGA_BLANK_N, //blanking signal
    output VGA_SYNC_N,  //syncing sigal
    output VGA_CLK,  //25Mhz for monitor
    output [9:0] VGA_R, //VGA_R amount
    output [9:0] VGA_G, //VGA_G amount
    output [9:0] VGA_B //VGA_B amount
);

//PART1: CLOCK & SYNC, do NOT TOUCH PLSSS

    //dividing de2 clock into monitor clock
    reg clock_25;
    always @(posedge CLOCK_50) begin
        clock_25 <= ~clock_25;
    end
    assign VGA_CLK = clock_25;

    //pixel coordinate incrementors (for drawing)
    reg [9:0] h_count = 0;
    reg [9:0] v_count = 0;

    always @(posedge clock_25) begin
        if (h_count == 799) begin
            h_count <= 0;
            if (v_count == 524) 
                v_count <= 0;
            else 
                v_count <= v_count + 1;
        end else begin
            h_count <= h_count + 1;
        end
    end

    //sync pulses for 640x480 at 60Hz ? not sure wut this is
    assign VGA_HS = (h_count >= 656 && h_count < 752) ? 1'b0 : 1'b1;
    assign VGA_VS = (v_count >= 490 && v_count < 492) ? 1'b0 : 1'b1;
    
    //blanking is 1 when in resolution area, 0 otherwise
    assign VGA_BLANK_N = (h_count < 640 && v_count < 480) ? 1'b1 : 1'b0;
    assign VGA_SYNC_N = 1'b1; // Tie high for standard VGA


//PART 2: Graphics Constants
    parameter TRANSPARENT = 8'hFF; // Assuming FF is magenta

    //Backdrop 
    parameter BG_W  = 200;
    parameter BG_H  = 100;
    parameter BG_START_X = 220; // Centered on 640 screen
    parameter BG_START_Y = 190; // Centered on 480 screen

    //Character sprites 
    parameter SPR_W = 65;
    parameter SPR_H = 40;
    parameter PIXELS_PER_FRAME = 2600; // 65 * 40

    //Health points
    parameter HP_W  = 52;
    parameter HP_H  = 6;

//PART 3: Bounding boxes 
    wire in_bg = (h_count >= BG_START_X && h_count < BG_START_X + BG_W && 
                  v_count >= BG_START_Y && v_count < BG_START_Y + BG_H);

    wire in_p1 = (h_count >= p1_x && h_count < p1_x + SPR_W && 
                  v_count >= p1_y && v_count < p1_y + SPR_H);
                  
    wire in_p2 = (h_count >= p2_x && h_count < p2_x + SPR_W && 
                  v_count >= p2_y && v_count < p2_y + SPR_H);

    // --- Dynamic Health Bars ---
    wire [10:0] p1_hp_x_start = BG_START_X + 30;
    wire [10:0] hp_y_start    = BG_START_Y + 135;
    
    wire in_p1_hp_border = (h_count >= p1_hp_x_start - 1 && h_count <= p1_hp_x_start + HP_W && 
                            v_count >= hp_y_start - 1 && v_count <= hp_y_start + HP_H);
                            
    wire in_p1_hp_fill   = (h_count >= p1_hp_x_start && h_count < p1_hp_x_start + p1_hp && 
                            v_count >= hp_y_start && v_count < hp_y_start + HP_H);

    wire [10:0] p2_hp_x_end   = BG_START_X + BG_W - 30;
    wire [10:0] p2_hp_x_start = p2_hp_x_end - HP_W;
    
    wire in_p2_hp_border = (h_count >= p2_hp_x_start - 1 && h_count <= p2_hp_x_end && 
                            v_count >= hp_y_start - 1 && v_count <= hp_y_start + HP_H);
                            
    wire in_p2_hp_fill   = (h_count >= (p2_hp_x_end - p2_hp) && h_count < p2_hp_x_end && 
                            v_count >= hp_y_start && v_count < hp_y_start + HP_H);

//PART 4: Memory Address Math 
    // Background
    assign bg_rom_addr = ((v_count - BG_START_Y) * BG_W) + (h_count - BG_START_X);

    // Sprites (Standard coordinate math, no flipping)
    wire [10:0] p1_local_y = v_count - p1_y;
    wire [10:0] p1_local_x = h_count - p1_x;
    
    wire [10:0] p2_local_y = v_count - p2_y;
    wire [10:0] p2_local_x = h_count - p2_x;

    // Placeholder base addresses for states
    reg [16:0] p1_base, p2_base;
    always @(*) begin
        case(p1_state)
            4'd0: p1_base = 17'd0;      // IDLE
            4'd3: p1_base = 17'd26000;  // PUNCH (Example offset)
            default: p1_base = 17'd0;
        endcase
        p2_base = 17'd0; 
    end

    // The Final ROM Requests
    always @(*) begin
        if (in_p1) p1_rom_addr = p1_base + (p1_frame * PIXELS_PER_FRAME) + (p1_local_y * SPR_W) + p1_local_x;
        else p1_rom_addr = 0;

        if (in_p2) p2_rom_addr = p2_base + (p2_frame * PIXELS_PER_FRAME) + (p2_local_y * SPR_W) + p2_local_x;
        else p2_rom_addr = 0;
    end

//PART 5: Layering
    reg [7:0] final_color_8bit;

    always @(*) begin
        if (VGA_BLANK_N) begin
            // LAYER 1: UI Borders (White)
            if ((in_p1_hp_border && !in_p1_hp_fill) || (in_p2_hp_border && !in_p2_hp_fill))
                final_color_8bit = 8'hFC; // Assign a white index from your palette

            // LAYER 2: UI Fill (Health Color)
            else if (in_p1_hp_fill || in_p2_hp_fill)
                final_color_8bit = 8'hE0; // Assign a red/green index from your palette


            // LAYER 3: Player 1 Sprite
            else if (in_p1 && p1_rom_data != TRANSPARENT)
                final_color_8bit = p1_rom_data;
            
            // LAYER 4: Player 2 Sprite
            else if (in_p2 && p2_rom_data != TRANSPARENT)
                final_color_8bit = p2_rom_data;
            
            // LAYER 5: Background Arena
            else if (in_bg)
                final_color_8bit = bg_rom_data;
            
            // LAYER 6: Outside Arena
            else
                final_color_8bit = 8'h00; // Black screen around the 200x100 box
                
        end else begin
            final_color_8bit = 8'h00; // Must be black during sync pulses
        end
    end

    // =========================================================================
    // PART 6: COLOR DECODER (8-bit to 30-bit DE2-115 VGA)
    // =========================================================================
    always @(*) begin
        case(final_color_8bit)
            8'h00: begin VGA_R = 10'h000; VGA_G = 10'h000; VGA_B = 10'h000; end // Black
            8'hFC: begin VGA_R = 10'h3FF; VGA_G = 10'h3FF; VGA_B = 10'h3FF; end // HP Border White
            8'hE0: begin VGA_R = 10'h000; VGA_G = 10'h3FF; VGA_B = 10'h000; end // HP Fill Green
            default: begin 
                VGA_R = {final_color_8bit[7:5], 7'b0}; 
                VGA_G = {final_color_8bit[4:2], 7'b0}; 
                VGA_B = {final_color_8bit[1:0], 8'b0}; 
            end
        endcase
    end

endmodule
