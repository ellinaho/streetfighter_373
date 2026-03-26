module graphics(
    input CLOCK_50,

    // Inputs from game logic
    input [9:0] p1_x, 
    input [9:0] p1_y,
    input [3:0] p1_state,       
    input [2:0] p1_frame,       
    input [7:0] p1_hp,          

    input [9:0] p2_x,
    input [9:0] p2_y,
    input [3:0] p2_state,
    input [2:0] p2_frame,
    input [7:0] p2_hp,
    
    // ROM Connections
    output reg [16:0] p1_rom_addr, 
    output reg [16:0] p2_rom_addr,
    output reg [14:0] bg_rom_addr, // Added as reg to fix the assign error
    
    input [7:0] p1_rom_data, 
    input [7:0] p2_rom_data,
    input [7:0] bg_rom_data, // Added background input
    
    // Physical VGA Outputs (Now all 'reg' to work inside always blocks)
    output VGA_HS, 
    output VGA_VS, 
    output VGA_BLANK_N, 
    output VGA_SYNC_N,  
    output VGA_CLK,  
    output reg [9:0] VGA_R, 
    output reg [9:0] VGA_G, 
    output reg [9:0] VGA_B 
);

// --- PART 1: CLOCK & SYNC ---
    reg clock_25 = 0;
    always @(posedge CLOCK_50) clock_25 <= ~clock_25;
    assign VGA_CLK = clock_25;

    reg [9:0] h_count = 0;
    reg [9:0] v_count = 0;

    always @(posedge clock_25) begin
        if (h_count == 799) begin
            h_count <= 0;
            if (v_count == 524) v_count <= 0;
            else v_count <= v_count + 1;
        end else h_count <= h_count + 1;
    end

    assign VGA_HS = (h_count >= 656 && h_count < 752) ? 1'b0 : 1'b1;
    assign VGA_VS = (v_count >= 490 && v_count < 492) ? 1'b0 : 1'b1;
    assign VGA_BLANK_N = (h_count < 640 && v_count < 480) ? 1'b1 : 1'b0;
    assign VGA_SYNC_N = 1'b1; 

// --- PART 2: CONSTANTS ---
    parameter TRANSPARENT = 8'hFF; 
    parameter BG_W  = 200;
    parameter BG_H  = 100;
    parameter BG_START_X = 220; 
    parameter BG_START_Y = 190; 

    parameter SPR_W = 65;
    parameter SPR_H = 40;
    parameter PIXELS_PER_FRAME = 2600; 

    parameter HP_W  = 52;
    parameter HP_H  = 6;

// --- PART 3: BOUNDING BOXES ---
    wire in_bg = (h_count >= BG_START_X && h_count < BG_START_X + BG_W && 
                  v_count >= BG_START_Y && v_count < BG_START_Y + BG_H);

    wire in_p1 = (h_count >= p1_x && h_count < p1_x + SPR_W && 
                  v_count >= p1_y && v_count < p1_y + SPR_H);
                  
    wire in_p2 = (h_count >= p2_x && h_count < p2_x + SPR_W && 
                  v_count >= p2_y && v_count < p2_y + SPR_H);

    wire [10:0] p1_hp_x_start = BG_START_X + 30;
    wire [10:0] hp_y_start    = BG_START_Y + 110; // Adjusted to be closer to arena
    
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

// --- PART 4: ADDRESS MATH ---
    wire [10:0] p1_local_y = v_count - p1_y;
    wire [10:0] p1_local_x = h_count - p1_x;
    wire [10:0] p2_local_y = v_count - p2_y;
    wire [10:0] p2_local_x = h_count - p2_x;

    reg [16:0] p1_base, p2_base;
    always @(*) begin
        case(p1_state)
            4'd3: p1_base = 17'd26000; 
            default: p1_base = 17'd0;
        endcase
        p2_base = 17'd0; 
    end

    // ROM Address Logic
    always @(*) begin
        // Background
        if (in_bg) bg_rom_addr = ((v_count - BG_START_Y) * BG_W) + (h_count - BG_START_X);
        else bg_rom_addr = 0;

        // Player 1
        if (in_p1) p1_rom_addr = p1_base + (p1_frame * PIXELS_PER_FRAME) + (p1_local_y * SPR_W) + p1_local_x;
        else p1_rom_addr = 0;

        // Player 2
        if (in_p2) p2_rom_addr = p2_base + (p2_frame * PIXELS_PER_FRAME) + (p2_local_y * SPR_W) + p2_local_x;
        else p2_rom_addr = 0;
    end

// --- PART 5: LAYERING ---
    reg [7:0] final_color_8bit;

    always @(*) begin
        if (VGA_BLANK_N) begin
            if ((in_p1_hp_border && !in_p1_hp_fill) || (in_p2_hp_border && !in_p2_hp_fill))
                final_color_8bit = 8'hFC; // White
            else if (in_p1_hp_fill || in_p2_hp_fill)
                final_color_8bit = 8'hE0; // Green/Red
            else if (in_p1 && p1_rom_data != TRANSPARENT)
                final_color_8bit = p1_rom_data;
            else if (in_p2 && p2_rom_data != TRANSPARENT)
                final_color_8bit = p2_rom_data;
            else if (in_bg)
                final_color_8bit = bg_rom_data;
            else
                final_color_8bit = 8'h00; // Black
        end else begin
            final_color_8bit = 8'h00;
        end
    end

// --- PART 6: COLOR DECODER ---
    always @(*) begin
        case(final_color_8bit)
            8'h00: begin VGA_R = 10'd0;   VGA_G = 10'd0;   VGA_B = 10'd0;   end
            8'hFC: begin VGA_R = 10'd1023; VGA_G = 10'd1023; VGA_B = 10'd1023; end
            8'hE0: begin VGA_R = 10'd0;   VGA_G = 10'd1023; VGA_B = 10'd0;   end
            default: begin 
                // Conversion from 8-bit (RRRGGGBB) to 10-bit VGA
                VGA_R = {final_color_8bit[7:5], 7'b0}; 
                VGA_G = {final_color_8bit[4:2], 7'b0}; 
                VGA_B = {final_color_8bit[1:0], 8'b0}; 
            end
        endcase
    end

endmodule