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

//Parameters
    //Coordinates
    parameter FLOOR_Y      = 10'd250; //where player feet are
    parameter SPRITE_H     = 10'd72; //change 
    parameter SPRITE_W     = 10'd45; //change
    parameter GROUND_LEVEL = FLOOR_Y - SPRITE_H; //top left y of sprite when character on floor
    parameter GAME_W = 10'd370;
    parameter GAME_H = 10'd260;

    //Player action states 
    parameter IDLE = 0;
    parameter WALK = 1;
    parameter JUMP_ONLY = 2;
    parameter PUNCH_ONLY = 3;
    parameter JUMP_PUNCH = 4;
    parameter ATTACKED = 5;
    parameter WIN = 6;
    parameter LOSE = 7;

    //Game states
    parameter START = 2'b0; //ready startup
    parameter PLAY = 2'b1; //playing the game
    parameter KO = 2'b2; //KO scene

    //Conventions
    parameter RIGHT = 1'b0;
    parameter LEFT = 1'b1;

    //Animations
    parameter IDLE_FRAMES = 10; //change
    parameter WALK_SPEED = 10'd2; // 120 pixels per second at 60Hz = exactly 2 pixels per frame
    parameter WALK_FRAMES = 12; // Change this whenever you want!
    parameter PUNCH_FRAMES = 6;
    parameter JUMP_FRAMES = 6;
    parameter JUMP_SPEED_X = 10'd3; //108 pixels per 0.6 seconds
    parameter JUMP_SPEED_Y = SPRITE_H/ 18;


//Registers
    // Player 1
    reg [9:0] p1_x = 10'd10; //sprite top left coordinate
    reg [9:0] p1_y = GROUND_LEVEL; 
    reg p1_dir = RIGHT;     
    reg [3:0] p1_state = IDLE; 
    reg [3:0] p1_frame = 4'd0; //change bit size later
    reg [7:0] p1_hp = 8'd125;     // Static for now, change

    // Player 2
    reg [9:0] p2_x = GAME_W - SPRITE_W;
    reg [9:0] p2_y = GROUND_LEVEL;
    reg p2_dir = LEFT;            // starts facing left 
    reg [3:0] p2_state = IDLE;   
    reg [3:0] p2_frame = 3'd0; //change bit size later
    reg [7:0] p2_hp = 8'd125;     //change

    // Game State 
    reg [1:0] game_state = START; 

    // Timing Registers
    reg [3:0] anim_timer1 = 4'd0;
    reg [3:0] anim_timer2 = 4'd0;
    reg [3:0] prev_state1 = IDLE;
    reg [3:0] prev_state2 = IDLE;


//updating coordinate and frame to draw
    always @(negedge VGA_VS) begin
    //Game State
    case(game_state)
        START: begin
            //animate players idle
            anim_timer1 <= anim_timer1 + 1;
            if (anim_timer1 >= (60/IDLE_FRAMES - 1)) begin
                anim_timer1 <= 0;
                if (p1_frame >= (IDLE_FRAMES - 1)) 
                    p1_frame <= 0;
                    p2_frame <= 0;
                else 
                    p1_frame <= p1_frame + 1;
                    p2_frame <= p2_frame + 1;
            end
        end
        PLAY: begin
        //Player 1 
            if (p1_state != prev_state1) begin
                p1_frame   <= 0;    // Reset to the first picture of the new move
                anim_timer1 <= 0;    // Reset the clock for the new move
                prev_state1 <= p1_state; // Record that we've now handled this state
            end
            case(p1_state)
                IDLE: begin
                    anim_timer1 <= anim_timer1 + 1;
                    if (anim_timer1 >= (60/IDLE_FRAMES - 1)) begin
                        anim_timer1 <= 0;
                        if (p1_frame >= (IDLE_FRAMES - 1)) 
                            p1_frame <= 0;
                        else 
                            p1_frame <= p1_frame + 1'b1;
                    end
                end    
                WALK: begin
                    //coordinate
                    if (p1_dir == RIGHT) begin
                        // Move Right (Optional: add a screen boundary check here later) change
                        p1_x <= p1_x + WALK_SPEED; 
                    end else begin
                        // Move Left
                        p1_x <= p1_x - WALK_SPEED;
                    end

                    //12 art frames in 1 second, 60 vga frames per second
                    anim_timer1 <= anim_timer1 + 1;
                    //Wait for 5 VGA frames 
                    if (anim_timer1 >= (60 /WALK_FRAMES - 1)) begin 
                        anim_timer1 <= 0;
                        //Cycle through 12 frames (0 to 11)
                        if (p1_frame >= (WALK_FRAMES - 1)) 
                            p1_frame <= 0;
                        else 
                            p1_frame <= p1_frame + 1;
                    end
                end
                PUNCH_ONLY: begin
                    anim_timer1 <= anim_timer1 + 1;
                    //take 0.2 seconds
                    if (anim_timer1 >= (12/PUNCH_FRAMES - 1)) begin
                        anim_timer1 <= 0;
                        // Check if we reached the end of the 6 frames
                        if (p1_frame >= (PUNCH_FRAMES - 1)) begin
                            p1_state <= IDLE; // Auto-return to IDLE when done
                            p1_frame <= 0;
                        end else begin
                            p1_frame <= p1_frame + 1;
                        end
                    end
                end
                JUMP_ONLY: begin
                    // x coordinate movement 
                    if (p1_dir == RIGHT) begin
                        // Move right, but don't jump past the right edge of the screen
                        if (p1_x < (GAME_W - SPRITE_W)) p1_x <= p1_x + JUMP_SPEED_X;
                    end else begin
                        // Move left, but don't jump past the left edge (0)
                        if (p1_x > JUMP_SPEED_X) p1_x <= p1_x - JUMP_SPEED_X;
                    end

                    // y coordinate movement
                    // First half of the animation: Going UP
                    if (p1_frame < 3) begin
                        p1_y <= p1_y - JUMP_SPEED_Y; 
                    end 
                    // Second half of the animation: Going DOWN
                    else begin
                        p1_y <= p1_y + JUMP_SPEED_Y;
                    end

                    //animation
                    anim_timer1 <= anim_timer1 + 1;
                    if (anim_timer1 >= (32/JUMP_FRAMES - 1)) begin
                        anim_timer1 <= 0;
                        // Check if we hit the final landing frame
                        if (p1_frame >= (JUMP_FRAMES - 1)) begin
                            p1_state <= IDLE;             // Landed! Back to standing.
                            p1_frame <= 0;
                            p1_y     <= GROUND_LEVEL;     // Safety snap perfectly to the floor
                        end else begin
                            p1_frame <= p1_frame + 1;
                        end
                    end
                end
                default: p1_state <= IDLE;
            endcase
        //Player 2
            if (p2_state != prev_state2) begin
                p2_frame   <= 0;    // Reset to the first picture of the new move
                anim_timer2 <= 0;    // Reset the clock for the new move
                prev_state2 <= p2_state; // Record that we've now handled this state
            end
            case(p2_state)
                IDLE: begin
                    anim_timer2 <= anim_timer2 + 1;
                    if (anim_timer2 >= (60/IDLE_FRAMES - 1)) begin
                        anim_timer2 <= 0;
                        if (p2_frame >= (IDLE_FRAMES - 1)) 
                            p2_frame <= 0;
                        else 
                            p2_frame <= p2_frame + 1'b1;
                    end
                end
                default: p2_state <= IDLE;
            endcase
        end

    endcase
    
        
    end

//ROM WIRES
    wire [16:0] p1_rom_addr, p2_rom_addr;
    wire [14:0] bg_rom_addr;
    wire [7:0] p1_rom_data, p2_rom_data, bg_rom_data;

//HARDWARE ROM
    p1_sprite_rom player1_memory (.address(p1_rom_addr), .clock(CLOCK_50), .q(p1_rom_data));
    p2_sprite_rom player2_memory (.address(p2_rom_addr), .clock(CLOCK_50), .q(p2_rom_data));
    bg_sprite_rom background_memory (.address(bg_rom_addr), .clock(CLOCK_50), .q(bg_rom_data));

//call graphics, TODO: ensure inputs are all right
    graphics my_graphics (
        .CLOCK_50   (CLOCK_50),
        .game_state (game_state),

        .p1_x       (p1_x),
        .p1_y       (p1_y),
        .p1_state   (p1_state),
        .p1_frame   (p1_frame),
        .p1_dir     (p1_dir),
        .p1_hp      (p1_hp),

        .p2_x       (p2_x),
        .p2_y       (p2_y),
        .p2_state   (p2_state),
        .p2_frame   (p2_frame),
        .p2_dir     (p2_dir),
        .p2_hp      (p2_hp),
      
        .p1_rom_addr(p1_rom_addr),
        .p2_rom_addr(p2_rom_addr),
        .bg_rom_addr(bg_rom_addr),
        
        .p1_rom_data(p1_rom_data),
        .p2_rom_data(p2_rom_data),
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