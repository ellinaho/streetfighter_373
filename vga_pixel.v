module pixel(
    input CLOCK_50,
    output reg [14:0] bg_rom_addr, 
    output reg [16:0] p1_rom_addr, 
    input [7:0] bg_rom_data, 
    input [7:0] p1_rom_data, 

    input [9:0] p1_x, 
    input [9:0] p1_y, 
    input [3:0] p1_state,  
    input [3:0] p1_frame,   

    output VGA_HS, 
    output VGA_VS, 
    output VGA_BLANK_N, 
    output VGA_SYNC_N,  
    output VGA_CLK,  
    output reg [7:0] VGA_R, 
    output reg [7:0] VGA_G, 
    output reg [7:0] VGA_B 
);

//CLOCK & SYNC
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

// Parameters 

    parameter TRANSPARENT = 8'hE3; //magenta
    parameter GAME_W = 160;
    parameter GAME_H = 120;

    parameter SPRITE_W = 64; 
    parameter SPRITE_H = 53;
    parameter PIXELS_PER_FRAME = SPRITE_W * SPRITE_H;

    //player state
    parameter IDLE = 0;
    parameter WALK = 1;
    parameter PUNCH = 2;

// ADDRESS MATH & MIRRORING ---
    wire [7:0] logic_h = h_count[9:2]; // Bits [9,8,7,6,5,4,3,2] -> Max value 159
    wire [6:0] logic_v = v_count[9:2]; // Bits [9,8,7,6,5,4,3,2] -> Max value 119

    wire bg_box = (logic_h < GAME_W && logic_v < GAME_H);
    wire p1_box = (logic_h >= p1_x && logic_h < p1_x + SPRITE_W && 
                   logic_v >= p1_y && logic_v < p1_y + SPRITE_H);

    // Player 1 Math
    wire [10:0] p1_local_y = logic_v - p1_y; 
    wire [9:0]  p1_local_x = logic_h - p1_x;

    //base address
    reg [16:0] p1_base;
    always @(*) begin
        case(p1_state)
            IDLE: p1_base = 0;
            WALK: p1_base = 13568;
            PUNCH: p1_base = 30528;
            default: p1_base = 0;
        endcase
    end

    // ROM Address Assignment
    always @(*) begin
        if (bg_box) bg_rom_addr = (logic_v * GAME_W) + logic_h;
        else bg_rom_addr = 0;

        if (p1_box) p1_rom_addr = p1_base + (p1_frame * PIXELS_PER_FRAME) + (p1_local_y * SPRITE_W) + p1_local_x;
        else p1_rom_addr = 0;
    end

// LAYERING 
    reg [7:0] final_color_8bit;
    always @(*) begin
        if (VGA_BLANK_N) begin
            if (p1_box && p1_rom_data != TRANSPARENT)
                final_color_8bit = p1_rom_data;
            else if (bg_box)
                final_color_8bit = bg_rom_data; // Background is all the way in back
            else
                final_color_8bit = 8'h00; // Black screen boundary
        end else begin
            final_color_8bit = 8'h00; // MUST be 0 during blanking!
        end
    end

    // --- PART 6: COLOR DECODER ---
    always @(*) begin
        case(final_color_8bit)
            8'h00: begin VGA_R = 10'd0;    VGA_G = 10'd0;    VGA_B = 10'd0;    end // Black
            8'hFC: begin VGA_R = 10'd1023; VGA_G = 10'd1023; VGA_B = 10'd1023; end // White
            8'hE0: begin VGA_R = 10'd1023; VGA_G = 10'd0;    VGA_B = 10'd0;    end // Red
            8'hF9: begin VGA_R = 10'd1023; VGA_G = 10'd876;  VGA_B = 10'd341;  end // Yellow
            
            default: begin 
                VGA_R = {final_color_8bit[7:5], 5'b0};
                VGA_G = {final_color_8bit[4:2], 5'b0};
                VGA_B = {final_color_8bit[1:0], 6'b0};
            end
        endcase
    end

endmodule
