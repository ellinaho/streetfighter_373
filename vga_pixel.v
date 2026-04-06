module pixel(
    input CLOCK_50,

    //rom stuff
    output reg [14:0] bg_rom_addr, 
    output reg [16:0] p1_rom_addr, 
    output reg [16:0] p2_rom_addr, 
    output reg [16:0] elem_rom_addr,
    input [7:0] bg_rom_data, 
    input [7:0] p1_rom_data, 
    input [7:0] p2_rom_data, 
    input [7:0] elem_rom_data,

    //player info
    input [9:0] p1_x, 
    input [9:0] p1_y, 
    input [3:0] p1_state,  
    input [3:0] p1_frame,   
    input [7:0] p1_hp, //change bit size
    input p1_charging,
    input [4:0] p1_charge, //change bit size
    input p1_dir,

    input [9:0] p2_x, 
    input [9:0] p2_y, 
    input [3:0] p2_state,  
    input [3:0] p2_frame,   
    input [7:0] p2_hp,
    input p2_charging,
    input [4:0] p2_charge, //change bit size
    input p2_dir,

    //game info
    input [1:0] game_state;
    input [6:0] time_left;

    //vga stuff
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

    reg [9:0] logic_h = 0;
    reg [9:0] logic_v = 0;

    always @(posedge clock_25) begin
        if (logic_h == 799) begin
            logic_h <= 0;
            if (logic_v == 524) logic_v <= 0;
            else logic_v <= logic_v + 1;
        end else logic_h <= logic_h + 1;
    end

    assign VGA_HS = (logic_h >= 656 && logic_h < 752) ? 1'b0 : 1'b1;
    assign VGA_VS = (logic_v >= 490 && logic_v < 492) ? 1'b0 : 1'b1;
    assign VGA_BLANK_N = (logic_h < 640 && logic_v < 480) ? 1'b1 : 1'b0;
    assign VGA_SYNC_N = 1'b1;


//helpers
    parameter TRANSPARENT = 8'hE3; //magenta

    function in_box;
        input [9:0] px;    // current VGA X
        input [8:0] py;    // current VGA Y
        input [9:0] box_x; // Box start X
        input [8:0] box_y; // Box start Y
        input [9:0] box_w; // Box width
        input [8:0] box_h; // Box height
        begin
            in_box = (px >= box_x && px < (box_x + box_w) && 
                    py >= box_y && py < (box_y + box_h));
        end
    endfunction
    
// ADDRESS MATH (assuming face right)
    wire [7:0] logic_h = logic_h[9:2]; // Bits [9,8,7,6,5,4,3,2] -> Max value 159
    wire [6:0] logic_v = logic_v[9:2]; // Bits [9,8,7,6,5,4,3,2] -> Max value 119

//player sprite boxes
    parameter SPRITE_H = 53, SPRITE_W = 64;
    wire p1_box = in_box(logic_h, logic_v, p1_x, p1_y, SPRITE_W, SPRITE_H);
    wire p2_box = in_box(logic_h, logic_v, p2_x, p2_y, SPRITE_W, SPRITE_H);

//HP bar boxes

    parameter P1_HP_X_START = 21, P2_HP_X_END = 138, HP_Y = 6;
    parameter HP_W = 50, HP_H = 3;

    wire p1_hp_fill = in_box(logic_h, logic_v, P1_HP_X_START, HP_Y, p1_hp, HP_H);  
    wire p2_hp_fill = in_box(logic_h, logic_v, (P2_HP_X_END - p2_hp), HP_Y, p2_hp, HP_H);
    wire p1_hp_inner = in_box(logic_h, logic_v, P1_HP_X_START, HP_Y, HP_W, HP_H); 
    wire p2_hp_inner = in_box(logic_h, logic_v, (P2_HP_X_END - HP_W), HP_Y, HP_W, HP_H);
    wire p1_hp_outer = in_box(logic_h, logic_v, P1_HP_X_START-1, HP_Y-1, HP_W+2, HP_H+2); 
    wire p2_hp_outter = in_box(logic_h, logic_v, (P2_HP_X_END - HP_W)-1, HP_Y-1, HP_W+2, HP_H+2);
    wire p1_hp_border = p1_hp_outter && ~p1_hp_inner;
    wire p2_hp_border = p2_hp_outter && ~p2_hp_inner;

//charging bar boxes
    parameter MUSCLE_X = 16, MUSCLE_Y = 4, MUSCLE_W = 32, MUSCLE_H = 3; //muscle y from top of sprite
    
    wire p1_muscle_fill = in_box(logic_h, logic_v, p1_x + MUSCLE_X, p1_y - MUSCLE_Y, p1_charge, MUSCLE_H);  
    wire p1_muscle_inner = in_box(logic_h, logic_v, p1_x + MUSCLE_X, p1_y - MUSCLE_Y, MUSCLE_W, MUSCLE_H); 
    wire p1_muscle_outer = in_box(logic_h, logic_v, p1_x + MUSCLE_X - 1, p1_y - MUSCLE_Y - 1, MUSCLE_W + 2, MUSCLE_H + 2); 
    wire p1_muscle_border = p1_muscle_outter && ~p1_muscle_inner;

    wire p2_muscle_fill = in_box(logic_h, logic_v, p2_x + MUSCLE_X, p2_y - MUSCLE_Y, p2_charge, MUSCLE_H);  
    wire p2_muscle_inner = in_box(logic_h, logic_v, p2_x + MUSCLE_X, p2_y - MUSCLE_Y, MUSCLE_W, MUSCLE_H); 
    wire p2_muscle_outer = in_box(logic_h, logic_v, p2_x + MUSCLE_X - 1, p2_y - MUSCLE_Y - 1, MUSCLE_W + 2, MUSCLE_H + 2); 
    wire p2_muscle_border = p2_muscle_outter && ~p2_muscle_inner;

//bg, time, title, ko, pfps boxes
    //background
    parameter GAME_W = 160, GAME_H = 120;
    wire bg_box = in_box(logic_h, logic_v, 0, 0, GAME_W, GAME_H);

    //titles
    wire title_box = in_box(); //change todo
    
    //pfps
    parameter PFP_Y = 5, PFP_X1 = 5, PFP_X2 = 141, PFP_W = 14, PFP_H = 17;
    wire p1_pfp_box = in_box(logic_h, logic_v, PFP_X1, PFP_Y, PFP_W, PFP_H); 
    wire p2_pfp_box = in_box(logic_h, logic_v, PFP_X2, PFP_Y, PFP_W, PFP_H); 

    //KO box
    parameter KO_X = 38, KO_Y = 42, KO_W = 80, KO_H = 53;
    wire ko_box = in_box(logic_h, logic_v, KO_X, KO_Y, KO_W, KO_H);

    //time...
    parameter TIME_X = 72, TIME_Y = 6, TIME_W = 16, TIME_H = 3; 
    wire time_fill = in_box(logic_h, logic_v, TIME_X, TIME_Y, time_left, TIME_H);  
    wire time_inner = in_box(logic_h, logic_v, TIME_X, TIME_Y, TIME_W, TIME_H);   
    wire time_outer = in_box(logic_h, logic_v, TIME_X, TIME_Y-1, TIME_W, TIME_H+2);   
    wire time_border = time_outter && ~time_inner;

//Choosing animation base addr
    parameter IDLE = 0, WALK = 1, PUNCH = 2, JUMP = 3; 
    parameter JUMP_PUNCH = 4, GOT_HIT = 5, LOSE = 6, WIN = 7;

    reg [16:0] p1_base;
    reg [16:0] p2_base;

    always @(*) begin
        case(p1_state)
            IDLE: p1_base = 0;
            WALK: p1_base = 13568;
            PUNCH: p1_base = 30528;
            JUMP: p1_base = 37312;
            JUMP_PUNCH: p1_base = 50880;
            GOT_HIT: p1_base = 67840;
            LOSE: p1_base = 74624;
            WIN: p1_base = 94976
            default: p1_base = 0;
        endcase
        case (p2_state)
            IDLE: p2_base = 0;
            WALK: p2_base = 13568;
            PUNCH: p2_base = 30528;
            JUMP: p2_base = 37312;
            JUMP_PUNCH: p2_base = 57664;
            GOT_HIT: p2_base = 84800;
            LOSE: p2_base = 91584;
            WIN: p2_base = 111936;
            default: p2_base = 0;
        endcase 
    end

// ROM Address Assignment
    parameter PIXELS_PER_FRAME = SPRITE_W * SPRITE_H;
    parameter LEFT = 1, RIGHT = 0;
    wire [10:0] p1_local_y = logic_v - p1_y; 
    wire [9:0]  p1_local_x = logic_h - p1_x;
    wire [9:0] p1_read_x = (p1_dir == LEFT) ? ((SPRITE_W - 1) - p1_local_x) : p1_local_x;

    wire [10:0] p2_local_y = logic_v - p2_y; 
    wire [9:0]  p2_local_x = logic_h - p2_x;
    wire [9:0]  p2_read_x = (p2_dir == LEFT) ? ((SPRITE_W - 1) - p2_local_x) : p2_local_x;

    always @(*) begin

        if (bg_box) bg_rom_addr = (logic_v * GAME_W) + logic_h;
        else bg_rom_addr = 0;

        if (p1_box) p1_rom_addr = p1_base + (p1_frame * PIXELS_PER_FRAME) + (p1_local_y * SPRITE_W) + p1_read_x;
        else p1_rom_addr = 0;

        if (p2_box) p2_rom_addr = p2_base + (p2_frame * PIXELS_PER_FRAME) + (p2_local_y * SPRITE_W) + p2_read_x;
        else p2_rom_addr = 0;

        if (p1_pfp_box) elem_rom_addr = (logic_v - 5) * 14 + (logic_h - 5);
        else if (p2_pfp_box) elem_rom_addr = 14 * 17 + (logic_v - 5) * 14 + (logic_h - 141);
        else if (title_box) elem_rom_addr = ?
        else if (ko_box) elem_rom_addr = ?
        else elem_rom_addr = 0;

    end

// LAYERING 
    parameter START = 0, GAME = 1, KO = 2;

    reg [7:0] final_color_8bit;
    always @(*) begin
        if (VGA_BLANK_N) begin
            final_color_8bit = bg_rom_data; 
            if (p1_box && p1_rom_data != TRANSPARENT) begin final_color_8bit = p1_rom_data; end
            if (p2_box && p2_rom_data != TRANSPARENT) begin final_color_8bit = p2_rom_data; end

            if (game_state == START) begin
                //streetfighter 373, flex to start game
                if (title_box && elem_rom_data != TRANSPARENT) begin final_color_8bit = elem_rom_data; end
            end
            if (game_state == START || game_state == GAME) begin
                //muscle chargeup
                if (p1_charging && p1_muscle_border) begin final_color_8bit = 8'hFF; end
                if (p1_charging && p1_muscle_fill) begin final_color_8bit = 8'h75; end
                if (p2_charging && p2_muscle_border) begin final_color_8bit = 8'hFF; end
                if (p2_charging && p2_muscle_fill) begin final_color_8bit = 8'h75; end
            end
            if (game_state == GAME || game_state == KO) begin
                //health points 
                if (p1_hp_fill || p2_hp_fill) begin final_color_8bit = 8'hA2; end //yellow
                if (p1_hp_border || p2_hp_border) begin final_color_8bit = 8'hFF; end //white
                //pfps
                if ((p1_pfp_box || p2_pfp_box) && elem_rom_data != TRANSPARENT) begin final_color_8bit = elem_rom_data; end
                //time
                if (time_fill) begin final_color_8bit = 8'hA8; end 
                if (time_border) begin final_color_8bit = 8'hFF; end //white
            end
            if (game_state == KO) begin 
                //ko screen
                if (ko_box && elem_rom_data != TRANSPARENT) begin final_color_8bit = elem_rom_data; end 
            end

        end else begin final_color_8bit = 8'h00; end
    end

// COLOR DECODER, write to vga
    always @(*) begin
        case(final_color_8bit)
            8'h00: begin VGA_R = 10'd0;    VGA_G = 10'd0;    VGA_B = 10'd0;    end // Black
            8'hA2: begin VGA_R = 10'd255;  VGA_G = 10'd209;  VGA_B = 10'd40;   end //yellow for hp
            8'hFF: begin VGA_R = 10'd255;  VGA_G = 10'd255;  VGA_B = 10'd255;  end //white
            8'h75: begin VGA_R = 10'd6;    VGA_G = 10'd204;  VGA_B = 10'd0;    end //green 
            8'hA8: begin VGA_R = 10'd40;    VGA_G = 10'd177;  VGA_B = 10'd255; end //blue
            
            default: begin 
                VGA_R = {final_color_8bit[7:5], 5'b0};
                VGA_G = {final_color_8bit[4:2], 5'b0};
                VGA_B = {final_color_8bit[1:0], 6'b0};
            end
        endcase
    end

endmodule
