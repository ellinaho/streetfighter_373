module top(
    input CLOCK_50,
    output VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK,
    output [7:0] VGA_R, VGA_G, VGA_B
);

    // --- 1. Parameters (160x120 Logic Space) ---
    parameter SPRITE_W     = 10'd64; 
    parameter SPRITE_H     = 10'd53;
    parameter GAME_W       = 10'd160; 
    parameter GAME_H       = 10'd120;
    parameter FLOOR_Y      = 10'd110; 
    parameter GROUND_Y     = FLOOR_Y - SPRITE_H;

    parameter IDLE=0, WALK=1, JUMP=2, PUNCH=3, HIT=5;
    parameter RIGHT=0, LEFT=1;

    // --- 2. Registers (Signed for Clipping) ---
    reg signed [10:0] p1_x = 10'd10; 
    reg signed [10:0] p1_y = GROUND_Y;
    reg p1_dir = RIGHT;     
    reg [3:0] p1_state = IDLE; 
    reg [3:0] p1_frame = 0;
    reg [7:0] p1_hp = 125;

    reg signed [10:0] p2_x = 10'd86; // Positioned so body is on right
    reg signed [10:0] p2_y = GROUND_Y;
    reg p2_dir = LEFT;            
    reg [3:0] p2_state = IDLE;   
    reg [3:0] p2_frame = 0;
    reg [7:0] p2_hp = 125;

    reg [1:0] game_state = 2'd1; // PLAY mode
    reg [5:0] anim_timer1, anim_timer2;

    // --- 3. Dynamic Box Offsets (The "Human" logic) ---
    reg [5:0] p1_off_l, p1_off_r, p1_off_t, p1_off_b;
    always @(*) begin
        case(p1_state)
            JUMP:    begin p1_off_l=17; p1_off_r=47; p1_off_t=5; p1_off_b=35; end 
            PUNCH:   begin p1_off_l=(p1_dir==RIGHT)?22:12; p1_off_r=(p1_dir==RIGHT)?52:42; p1_off_t=5; p1_off_b=50; end
            default: begin p1_off_l=17; p1_off_r=47; p1_off_t=5; p1_off_b=50; end
        endcase
    end

    // Alias Wires for Body Edges
    wire signed [10:0] p1_body_l = p1_x + p1_off_l;
    wire signed [10:0] p1_body_r = p1_x + p1_off_r;
    wire signed [10:0] p2_body_l = p2_x + 17; // Simple static for P2 example
    wire signed [10:0] p2_body_r = p2_x + 47;

    // --- 4. Movement & Animation Logic ---
    always @(negedge VGA_VS) begin
        if (game_state == 2'd1) begin
            // P1 Walk Logic
            if (p1_state == WALK) begin
                if (p1_dir == RIGHT && p1_body_r < GAME_W) p1_x <= p1_x + 1;
                else if (p1_dir == LEFT && p1_body_l > 0)  p1_x <= p1_x - 1;
                
                anim_timer1 <= anim_timer1 + 1;
                if (anim_timer1 >= 5) begin 
                    anim_timer1 <= 0;
                    p1_frame <= (p1_frame >= 11) ? 0 : p1_frame + 1;
                end
            end
            // ... add other state logic here
        end
    end

    // --- 5. ROM & Graphics Connections ---
    wire [16:0] p1_rom_addr, p2_rom_addr;
    wire [14:0] bg_rom_addr;
    wire [7:0] p1_rom_data, p2_rom_data, bg_rom_data;

    // You must have these ROM modules defined in your project!
    p1_sprite_rom p1_mem (.address(p1_rom_addr), .clock(CLOCK_50), .q(p1_rom_data));
    p2_sprite_rom p2_mem (.address(p2_rom_addr), .clock(CLOCK_50), .q(p2_rom_data));
    bg_sprite_rom bg_mem (.address(bg_rom_addr), .clock(CLOCK_50), .q(bg_rom_data));

    graphics my_vga (
        .CLOCK_50(CLOCK_50), .p1_x(p1_x), .p1_y(p1_y), .p1_state(p1_state), .p1_frame(p1_frame), .p1_dir(p1_dir),
        .p2_x(p2_x), .p2_y(p2_y), .p2_state(p2_state), .p2_frame(p2_frame), .p2_dir(p2_dir),
        .p1_rom_addr(p1_rom_addr), .p2_rom_addr(p2_rom_addr), .bg_rom_addr(bg_rom_addr),
        .p1_rom_data(p1_rom_data), .p2_rom_data(p2_rom_data), .bg_rom_data(bg_rom_data),
        .VGA_HS(VGA_HS), .VGA_VS(VGA_VS), .VGA_BLANK_N(VGA_BLANK_N), .VGA_SYNC_N(VGA_SYNC_N), .VGA_CLK(VGA_CLK),
        .VGA_R(VGA_R), .VGA_G(VGA_G), .VGA_B(VGA_B)
    );
endmodule