/*
Player state guide:
0 = Idle/Ready  | 1 = Walking | 2 = Punch Only | 3 = Jump Only | 4 = Punch + Jump 
5 = Got punched | 6 = K.O     | 7 = Victory
*/

module graphics(
    input CLOCK_50,
    
    input [1:0] game_state

    // Inputs from game logic
    input [9:0] p1_x //0 <= x <= 370 top left of sprite
    input [9:0] p1_y, //0 <= y <= 260 //top left of sprite
    input [3:0] p1_state,  
    input [2:0] p1_frame,       
    input [7:0] p1_hp, 

    input p1_dir, //0 for right, 1 for left
    input p2_dir,         

    input [9:0] p2_x,
    input [9:0] p2_y,
    input [3:0] p2_state,
    input [2:0] p2_frame,
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
    parameter TRANSPARENT = 8'hE3; //Magenta used for player sprites 
    parameter BG_W  = 370;
    parameter BG_H  = 260;
    parameter BG_START_X = 0;   //top left corner 
    parameter BG_START_Y = 0; 

    parameter PLAYER_SPR_W = 40; //change
    parameter PLAYER_SPR_H = 65;
    parameter PIXELS_PER_FRAME = 2600; 

    parameter HP_W  = 125;
    parameter HP_H  = 9;

// --- PART 3: BOUNDING BOXES ---
    wire bg_box = (h_count >= BG_START_X && h_count < BG_START_X + BG_W && 
                  v_count >= BG_START_Y && v_count < BG_START_Y + BG_H);

    wire p1_box = (h_count >= p1_x && h_count < p1_x + PLAYER_SPR_W && 
                  v_count >= p1_y && v_count < p1_y + PLAYER_SPR_H);

    wire p2_box = (h_count >= p2_x && h_count < p2_x + PLAYER_SPR_W && 
                  v_count >= p2_y && v_count < p2_y + PLAYER_SPR_H);

    wire [10:0] p1_hp_x_start = BG_START_X + 38;
    wire [10:0] hp_y_start    = BG_START_Y + 23;
    
    //wire p1_box_hp_border = (h_count >= p1_hp_x_start - 1 && h_count <= p1_hp_x_start + HP_W && v_count >= hp_y_start - 1 && v_count <= hp_y_start + HP_H);

    wire p1_box_hp_fill   = (h_count >= p1_hp_x_start && h_count < p1_hp_x_start + p1_hp && 
                            v_count >= hp_y_start && v_count < hp_y_start + HP_H);

    wire [10:0] p2_hp_x_end   = BG_START_X + BG_W - 38;
    wire [10:0] p2_hp_x_start = p2_hp_x_end - HP_W;

    // wire p2_box_hp_border = (h_count >= p2_hp_x_start - 1 && h_count <= p2_hp_x_end && v_count >= hp_y_start - 1 && v_count <= hp_y_start + HP_H);
   
    wire p2_box_hp_fill   = (h_count >= (p2_hp_x_end - p2_hp) && h_count < p2_hp_x_end && 
                            v_count >= hp_y_start && v_count < hp_y_start + HP_H);

// --- PART 4: ADDRESS MATH ---
    //coordinates within sprite, treat top left of player as (0,0)
    wire [10:0] p1_local_y = v_count - p1_y; 
    wire [9:0] p1_local_x_raw = h_count - p1_x; 
    wire [9:0] p1_local_x = (p1_dir) ? (SPR_W - 1 - p1_local_x_raw) : p1_local_x_raw;
    wire [10:0] p2_local_y = v_count - p2_y;
    wire [9:0] p2_local_x_raw = h_count - p2_x;
    wire [9:0] p2_local_x = (p2_dir) ? (SPR_W - 1 - p2_local_x_raw) : p2_local_x_raw;

    reg [16:0] p1_base, p2_base;
    
    // Base address lookup table based on state
    always @(*) begin
        // Player 1
        case(p1_state) //Change
            4'd0: p1_base = 17'd0;      // IDLE starts at 0
            4'd1: p1_base = 17'd5200;   // WALK starts after Idle
            4'd2: p1_base = 17'd18200;  // PUNCH starts after Walk
            default: p1_base = 17'd0;
        endcase

        // Player 2
        case(p2_state) //change
            4'd0: p2_base = 17'd0;
            4'd1: p2_base = 17'd5200;
            4'd2: p2_base = 17'd18200;
            default: p2_base = 17'd0;
        endcase
    end

    // ROM Address Logic
    always @(*) begin
        // Background
        if (bg_box) bg_rom_addr = ((v_count - BG_START_Y) * BG_W) + (h_count - BG_START_X);
        else bg_rom_addr = 0;

        // Player 1
        if (p1_box) p1_rom_addr = p1_base + (p1_frame * PIXELS_PER_FRAME) + (p1_local_y * PLAYER_SPR_W) + p1_local_x;
        else p1_rom_addr = 0;

        // Player 2
        if (p2_box) p2_rom_addr = p2_base + (p2_frame * PIXELS_PER_FRAME) + (p2_local_y * PLAYER_SPR_W) + p2_local_x;
        else p2_rom_addr = 0;
    end

// --- PART 5: LAYERING ---
    reg [7:0] final_color_8bit;
    always @(*) begin
        if (VGA_BLANK_N) begin
            if (p1_box_hp_fill || p2_box_hp_fill)
                final_color_8bit = 8'hF9; //yellow
            else if (p1_box && p1_rom_data != TRANSPARENT)
                final_color_8bit = p1_rom_data;
            else if (p2_box && p2_rom_data != TRANSPARENT)
                final_color_8bit = p2_rom_data;
            else if (bg_box)
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
            8'h00: begin VGA_R = 10'd0;    VGA_G = 10'd0;    VGA_B = 10'd0;    end // Black
            8'hFC: begin VGA_R = 10'd1023; VGA_G = 10'd1023; VGA_B = 10'd1023; end // White
            8'hE0: begin VGA_R = 10'd1023; VGA_G = 10'd0;    VGA_B = 10'd0;    end // Red
            8'hF9: begin VGA_R = 10'd1023; VGA_G = 10'd876;  VGA_B = 10'd341;  end // HP Yellow
            
            
            default: begin 
                VGA_R = {final_color_8bit[7:5], 5'b0};
                VGA_G = {final_color_8bit[4:2], 5'b0};
                VGA_B = {final_color_8bit[1:0], 6'b0};
            end
        endcase
    end

endmodule