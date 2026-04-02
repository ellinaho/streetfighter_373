module write_pixel(
    input CLOCK_50,
    
    input [1:0] game_state,

    // Inputs from game logic
    input [9:0] p1_x, 
    input [9:0] p1_y, 
    input [3:0] p1_state,  
    input [3:0] p1_frame,       
    input p1_dir, 
    input [7:0] p1_hp,

    input [9:0] p2_x,
    input [9:0] p2_y,
    input [3:0] p2_state,
    input [2:0] p2_frame,
    input p2_dir,
    input [7:0] p2_hp,
    
    // ROM Connections
    output reg [16:0] p1_rom_addr, 
    output reg [16:0] p2_rom_addr,
    output reg [14:0] bg_rom_addr, 
    
    input [7:0] p1_rom_data, 
    input [7:0] p2_rom_data,
    input [7:0] bg_rom_data, 
    
    // Physical VGA Outputs 
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
    
    //Coordinates & Sizes
    parameter GAME_W  = 370;
    parameter GAME_H  = 260;
    parameter BG_START_X = 0; //top left
    parameter BG_START_Y = 0; 

    parameter SPRITE_W = 10'd45; //change
    parameter SPRITE_H = 10'd65;
    parameter PIXELS_PER_FRAME = 2925; // 45 * 65

    parameter HP_W  = 125;
    parameter HP_H  = 9;

    //Player action state 
    parameter IDLE = 4'd0;
    parameter WALK = 4'd1;


//BOUNDING BOXES
    wire bg_box = (h_count >= BG_START_X && h_count < BG_START_X + GAME_W && 
                   v_count >= BG_START_Y && v_count < BG_START_Y + GAME_H);

    wire p1_box = (h_count >= p1_x && h_count < p1_x + SPRITE_W && 
                   v_count >= p1_y && v_count < p1_y + SPRITE_H);

    wire p2_box = (h_count >= p2_x && h_count < p2_x + SPRITE_W && 
                   v_count >= p2_y && v_count < p2_y + SPRITE_H);

    //health points on top 
    wire [10:0] p1_hp_x_start = BG_START_X + 38;
    wire [10:0] hp_y_start    = BG_START_Y + 23;
    wire p1_box_hp_fill       = (h_count >= p1_hp_x_start && h_count < p1_hp_x_start + p1_hp && 
                                 v_count >= hp_y_start && v_count < hp_y_start + HP_H);

    wire [10:0] p2_hp_x_end   = BG_START_X + GAME_W - 38;
    wire [10:0] p2_hp_x_start = p2_hp_x_end - HP_W;
    wire p2_box_hp_fill       = (h_count >= (p2_hp_x_end - p2_hp) && h_count < p2_hp_x_end && 
                                 v_count >= hp_y_start && v_count < hp_y_start + HP_H);

// ADDRESS MATH & MIRRORING ---
    //coordinates within sprite, treat top left as (0,0)
    // Player 1 Math
    wire [10:0] p1_local_y = v_count - p1_y; 
    wire [9:0]  p1_local_x_raw = h_count - p1_x; 
    wire [9:0]  p1_local_x = (p1_dir) ? (SPRITE_W - 1 - p1_local_x_raw) : p1_local_x_raw;

    // Player 2 Math
    wire [10:0] p2_local_y = v_count - p2_y; 
    wire [9:0]  p2_local_x_raw = h_count - p2_x; 
    wire [9:0]  p2_local_x = (p2_dir) ? (SPRITE_W - 1 - p2_local_x_raw) : p2_local_x_raw;

    // Base Addresses
    reg [16:0] p1_base, p2_base;
    always @(*) begin
        // Player 1, change
        case(p1_state)
            IDLE: p1_base = 17'd0;     
            WALK: p1_base = 17'd2925;  
            default: p1_base = 17'd0;
        endcase

        // Player 2, change
        case(p2_state)
            IDLE: p2_base = 17'd0;     // IDLE
            WALK: p2_base = 17'd2925;  // WALK 
            default: p2_base = 17'd0;
        endcase
    end

    // ROM Address Assignment
    always @(*) begin
        if (bg_box) bg_rom_addr = ((v_count - BG_START_Y) * GAME_W) + (h_count - BG_START_X);
        else bg_rom_addr = 0;

        if (p1_box) p1_rom_addr = p1_base + (p1_frame * PIXELS_PER_FRAME) + (p1_local_y * SPRITE_W) + p1_local_x;
        else p1_rom_addr = 0;

        if (p2_box) p2_rom_addr = p2_base + (p2_frame * PIXELS_PER_FRAME) + (p2_local_y * SPRITE_W) + p2_local_x;
        else p2_rom_addr = 0;
    end

// LAYERING 
    reg [7:0] final_color_8bit;
    always @(*) begin
        if (VGA_BLANK_N) begin
            if (p1_box_hp_fill || p2_box_hp_fill)
                final_color_8bit = 8'hF9; // Yellow HP Bar
            else if (p1_box && p1_rom_data != TRANSPARENT)
                final_color_8bit = p1_rom_data; // Player 1 is in front
            else if (p2_box && p2_rom_data != TRANSPARENT)
                final_color_8bit = p2_rom_data; // Player 2 is behind P1
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