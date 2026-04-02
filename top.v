module top(
    input CLOCK_50,

    // Physical VGA Pins on the DE2-115
    output VGA_HS,
    output VGA_VS,
    output VGA_BLANK_N,
    output VGA_SYNC_N,
    output VGA_CLK,
    output [7:0] VGA_R,
    output [7:0] VGA_G,
    output [7:0] VGA_B
);

//Game State & Physics
    parameter FLOOR_Y      = 10'd250;
    parameter SPRITE_H     = 10'd65; //change
    parameter SPRITE_W     = 10'd45; //change
    parameter GROUND_LEVEL = FLOOR_Y - SPRITE_H;

    reg [9:0] p1_x = 10'd10;
    reg [9:0] p1_y = GROUND_LEVEL; // NOW A REG so gravity can pull it down
    reg p1_dir = 1'b0; // 0 is moving right, 1 is moving left
    
    //player state params
    parameter IDLE = 4'd0;
    parameter WALKING = 4'd1;
    parameter PUNCH_ONLY = 4'd2;
    parameter JUMP_ONLY = 4'd3;

    //game state params
    parameter game_start = 2'd0;

    reg [3:0] p1_state = 4'd0; 
    reg [2:0] p1_frame = 3'd0; 
    wire [7:0] p1_hp = 8'd125; //change

    wire [9:0] p2_x = 10'd380;
    wire [9:0] p2_y = GROUND_LEVEL;

    reg [3:0] p2_state = 4'd0; 
    reg [2:0] p2_frame = 3'd0; 
    wire [7:0] p2_hp = 8'd25; //change

//animation
    reg [3:0] anim_timer = 0;

    always @(negedge VGA_VS) begin
        
        // --- 1. PHYSICS & GRAVITY ---
        if (p1_y < GROUND_LEVEL) begin
            p1_y <= p1_y + 10'd2; // Gravity: Fall down 2 pixels per frame
        end else if (p1_y >= GROUND_LEVEL) begin
            p1_y <= GROUND_LEVEL; // Snap to floor
            
            // If we were falling over from being hurt, and hit the ground, go back to idle
            if (p1_state == 4'd4) begin
                p1_state <= 4'd0;
            end
        end

        // --- 2. MOVEMENT LOGIC ---
        // For testing, we make P1 auto-patrol if they aren't hurt or punching
        if (p1_state == 4'd0 || p1_state == 4'd1) begin
            p1_state <= 4'd1; // Set state to WALK!
            
            if (p1_dir == 1'b0) begin
                p1_x <= p1_x + 1'b1;
                if (p1_x >= 10'd300) p1_dir <= 1'b1;
            end else begin
                p1_x <= p1_x - 1'b1;
                if (p1_x <= 10'd220) p1_dir <= 1'd0;
            end
        end

        // --- 3. ANIMATION LOGIC ---
        anim_timer <= anim_timer + 1;
        
        // Update frame every 5th screen draw (~12 fps)
        if (anim_timer == 4) begin 
            anim_timer <= 0;

            // Player 1 Animation Cycle
            case (p1_state)
                4'd0: begin // IDLE 
                    if (p1_frame >= 3'd1) p1_frame <= 3'd0;
                    else p1_frame <= p1_frame + 1'b1;
                end
                
                4'd1: begin // WALK 
                    if (p1_frame >= 3'd4) p1_frame <= 3'd0;
                    else p1_frame <= p1_frame + 1'b1;
                end
                
                4'd2: begin // PUNCH 
                    if (p1_frame >= 3'd2) begin 
                        p1_frame <= 3'd0;
                        p1_state <= 4'd0; // Auto-return to idle
                    end else begin
                        p1_frame <= p1_frame + 1'b1;
                    end
                end

                4'd3: begin // JUMP
                    p1_frame <= 3'd0; // Maybe just 1 static jumping frame?
                end

                4'd4: begin // HURT / FALLING OVER
                    // Play a 3-frame falling animation
                    if (p1_frame >= 3'd2) p1_frame <= 3'd2; // Stay on the last frame while falling
                    else p1_frame <= p1_frame + 1'b1;
                end
                
                default: p1_frame <= 3'd0;
            endcase

            p2_frame <= 3'd0; 
        end
    end

    // =========================================================
    // 2. ROM WIRES
    // =========================================================
    wire [16:0] p1_rom_addr, p2_rom_addr;
    wire [14:0] bg_rom_addr;

    wire [7:0] p1_rom_data;
    wire [7:0] p2_rom_data;
    wire [7:0] bg_rom_data;

    // =========================================================
    // 3. THE HARDWARE ROMS
    // =========================================================
    p1_sprite_rom player1_memory (
        .address (p1_rom_addr), 
        .clock   (CLOCK_50),
        .q       (p1_rom_data)   
    );

    p2_sprite_rom player2_memory (
        .address (p2_rom_addr),
        .clock   (CLOCK_50),
        .q       (p2_rom_data)
    );

    bg_sprite_rom background_memory (
        .address (bg_rom_addr),
        .clock   (CLOCK_50),
        .q       (bg_rom_data)
    );

    // =========================================================
    // 4. CALLING YOUR GRAPHICS MODULE
    // =========================================================
    graphics my_graphics (
        .CLOCK_50   (CLOCK_50),

        .p1_x       (p1_x),
        .p1_y       (p1_y),
        .p1_state   (p1_state),
        .p1_frame   (p1_frame),
        .p1_hp      (p1_hp),

        .p2_x       (p2_x),
        .p2_y       (p2_y),
        .p2_state   (p2_state),
        .p2_frame   (p2_frame),
        .p2_hp      (p2_hp),
      
        .p1_rom_addr(p1_rom_addr),
        .p2_rom_addr(p2_rom_addr),
        .p1_rom_data(p1_rom_data),
        .p2_rom_data(p2_rom_data),
        
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