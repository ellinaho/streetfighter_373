module psuedo();

    // hit mechanics
    reg [3:0] punch_mul;
    reg [3:0] kick_mul;

    localparam MAX_WIDTH = 640;
    localparam GRAVITY = 2;
    localparam GROUND_Y = 400;

    // Player 1 registers 
    reg [6:0]   p1_hp = 7'd100;
    reg [9:0]   p1_x = 10'd100; // Position on screen x-axis
    reg [9:0]   p1_y = 10'd100; // Position on screen y-axis
    reg [1:0]   p1_H_move;      // 00: idle, 01: right, 10: left
    reg	        p1_jump;	    // 0: idle, 1: jump
    reg	        p1_punch_valid;
    reg [2:0]   p1_punch_val;
    reg	        p1_kick_valid;
    reg [2:0]   p1_kick_val;
    reg [3:0]   p1_H_speed;
    reg [3:0]   p1_V_speed;
    reg 	    p1_PowerUp_valid;
    reg [2:0]   p1_PowerUp_val;

    // Player 2 registers
    reg [6:0]   p2_hp = 7'd100;
    reg [9:0]   p2_x = 10'd100; // Position on screen x-axis
    reg [9:0]   p2_y = 10'd100; // Position on screen y-axis
    reg [1:0]   p2_H_move;      // 00: idle, 01: right, 10: left
    reg	        p2_jump;	    // 0: idle, 1: jump
    reg	        p2_punch_valid;
    reg [2:0]   p2_punch_val;
    reg	        p2_kick_valid;
    reg [2:0]   p2_kick_val;
    reg [3:0]   p2_H_speed;
    reg [3:0]   p2_V_speed;
    reg 	    p2_PowerUp_valid;
    reg [2:0]   p2_PowerUp_val;


    // State definitions and transitions
    typedef enum {STARTUP, PLAY, GAMEOVER} state_t;
    state_t current_state, next_state;

    always @(posedge clk) begin
        case (current_state)
            STARTUP: begin
                if (p1_ready && p2_ready) current_state <= PLAY;
            end

            PLAY: begin
                if (p1_hp == 0 || p2_hp == 0) current_state <= GAMEOVER;
            end
        endcase
    end

    // character movements

    typedef enum {ON_GROUND, JUMPING, FALLING} state_vertical;
    typedef enum {IDLE, MOVING, ATTACK_ACTIVE, CHARGING, HIT_STUN} state_horizontal; // do we need like a stun phase?
    state_vertical p1V_move_state;
    state_horizontal p1H_move_state;

    wire collision;
     // defining hitbox, how close characters must be to hit each other
    assign collision = (p1_x < p2_x + 20) && (p1_x + 20 > p2_x) && (p1_y < p2_y + 20) && (p1_y + 20 > p2_y);

    // p1 movements

    // horizontal (left right, punches, kicks, charge ups)
    always @(posedge clk) begin
        if (current_state == PLAY) begin
            case (p1H_move_state)
                IDLE: begin
                    if (p1_punch_valid) p1H_move_state <= ATTACK_ACTIVE;
                    else if (p1_H_move != 2'b00) p1H_move_state <= MOVING;
                    else if (p1_PowerUp_valid)  p1H_move_state <= CHARGING;
                end

                MOVING: begin
                    // going right
                    if (p1_H_move == 2'b01) begin
                        if (p1_x + p1_H_speed < MAX_WIDTH) p1_x <= p1_x + p1_H_speed;
                        else    p1H_move_state <= IDLE;
                    end
                    // going left
                    else if (p1_H_move == 2'b10) begin
                        if (p1_x > p1_H_speed)  p1_x <= p1_x - p1_H_speed;
                        else    p1H_move_state <= IDLE;
                    end

                    if (p1_H_move == 2'b00) p1H_move_state <= IDLE;
                    if (p1_punch_valid) p1H_move_state <= ATTACK_ACTIVE;
                    if (p1_PowerUp_val) p1H_move_state <= CHARGING;
                end

                ATTACK_ACTIVE: begin
                    if (p1_punch_valid && collision && !p1_punch_lock) begin
                        p2_hp <= p2_hp - (p1_punch_val * punch_mul);
                        p1_punch_lock <= 1;
                    end
                    else if (p1_kick_valid && collision && !p1_kick_lock) begin
                        p2_hp <= p2_hp - (p1_kick_val * kick_mul);
                        p1_kick_lock <= 1;
                    end

                    if (!p1_punch_valid) p1_punch_lock <= 0;    // Reset lock
                    if (!p1_kick_valid) p1_kick_lock <= 0;    // Reset lock

                    if (!p1_punch_valid && !p1_kick_valid) begin
                        if (p1_H_move != 0'b00) p1H_move_state <= MOVING;
                        else p1H_move_state <= IDLE;
                    end
                    if (p1_PowerUp_val) p1H_move_state <= CHARGING;
                end

                CHARGING: begin
                    if (!p1_PowerUp_valid) begin
                        p1H_move_state <= IDLE;
                    end
                end
            endcase
        end
    end

    // vertical movements (mainly jumping)
    always @(posedge clk) begin
        if (current_state == PLAY) begin
            case (p1V_move_state)
                ON_GROUND: begin
                    p1_y <= GROUND_Y;
                    p1_V_speed <= 0;
                    if (p1_jump) p1V_move_state <= JUMPING;
                end
                JUMPING, FALLING: begin
                    p1_y <= p1_y + p1_V_speed;   // Update position
                    p1_V_speed <= p1_V_speed + GRAVITY; // Apply gravity
                    if (p1_y <= GROUND_Y) p1V_move_state <= ON_GROUND;
                end
            endcase
        end
    end


    // typedef enum {IDLE, MOVING, JUMPIMG, AIRBONE, ATTACK_ACTIVE, HIT_STUN} state_move;
    // state_move p1_move_state, p2_move_state;
    //
    // always @(posedge clk) begin
    //     if (current_state == PLAY) begin
    //         case (p1_move_state)
    //             IDLE: begin
    //                 if (p1_punch_valid) p1_move_state <= ATTACK_ACTIVE;
    //                 else if (p1_jump)    p1_move_state <= AIRBONE;
    //                 else if (p1_H_move != 2'b00) p1_move_state <= MOVING;
    //             end

    //             MOVING: begin
    //                 // going right
    //                 if (p1_H_move == 2'b01) begin
    //                     if (p1_x + p1_H_speed < MAX_WIDTH) p1_x <= p1_x + p1_H_speed;
    //                     else    p1_move_state <= IDLE;
    //                 end
    //                 // going left
    //                 else if (p1_H_move == 2'b10) begin
    //                     if (p1_x - p1_H_speed < 0)  p1_x <= p1_x - p1_H_speed;
    //                     else    p1_move_state <= IDLE;
    //                 end

    //                 if (p1_H_move == 2'b00) p1_move_state <= IDLE;
    //                 if (p1_punch_valid) p1_move_state <= ATTACK_ACTIVE;
    //             end

    //             JUMPING: begin
    //                 // only jumps when character is on the ground
    //                 if (p1_y == 0) begin
    //                     p1_y <= p1_y + p1_V_speed;
    //                     p1_move_state <= AIRBONE;
    //                 end
    //                 else begin
    //                     p1_move_state <= IDLE;
    //                 end
    //             end

    //             AIRBONE: begin
    //                 // only if the player is on the ground to jump again
    //                 if (p1_y == 0) begin
    //                     if (!p1_jump)   p1_move_state <= IDLE;
    //                     if (p1_punch_valid) p1_move_state <= ATTACK_ACTIVE;
    //                     else if (p1_H_move != 2'b00) p1_move_state <= MOVING;
    //                 end
    //                 else begin
    //                     if (p1_punch_valid) p1_move_state <= ATTACK_ACTIVE;
    //                     else if (p1_H_move != 2'b00) p1_move_state <= MOVING;
    //                     p1_y <= p1_y - GRAVITY;
    //                 end
    //             end

    //             ATTACK_ACTIVE: begin
    //                 if (p1_punch_valid && collision && !p1_punch_lock) begin
    //                     p2_hp <= p2_hp - (p1_punch_val * punch_mul);
    //                     p1_punch_lock <= 1;
    //                 end
    //                 else if (p1_kick_valid && collision && !p1_kick_lock) begin
    //                     p2_hp <= p2_hp - (p1_kick_val * kick_mul);
    //                     p1_kick_lock <= 1;
    //                 end

    //                 if (!p1_punch_valid) p1_punch_lock <= 0;    // Reset lock
    //                 if (!p1_kick_valid) p1_kick_lock <= 0;    // Reset lock

    //                 if (!p1_punch_valid && !p1_kick_valid) begin
    //                     if (p1_H_move != 0'b00) p1_move_state <= MOVING;
    //                     else if (p1_jump)   p1_move_state <= AIRBONE;
    //                     else p1_move_state <= IDLE;
    //                 end
    //             end

    //             HIT_STUN: begin

    //             end
    //         endcase
    //     end
    // end


    // wire collision;
    // assign collision = (p1_x < p2_x + 20) && (p1_x + 20 > p2_x) && (p1_y < p2_y + 20) && (p1_y + 20 > p2_y); // defining hitbox, how close characters must be to hit each other
    // // Sequential Health Update
    // always @(posedge clk) begin
    //     if (current_state == PLAY) begin
    //         if (p1_punch_valid && collision && !p1_punch_lock) begin
    //             p2_hp <= p2_hp - (p1_punch_val * punch_mul);
    //             p1_punch_lock <= 1;
    //         end
    //         else if (p1_kick_valid && collision && !p1_kick_lock) begin
    //             p2_hp <= p2_hp - (p1_kick_val * kick_mul);
    //             p1_kick_lock <= 1;
    //         end

    //         if (p2_punch_valid && collision && !p2_punch_lock) begin
    //             p1_hp <= p1_hp - (p2_punch_val * punch_mul);
    //             p2_punch_lock <= 1;
    //         end
    //         else if (p2_kick_valid && collision && !p2_kick_lock) begin
    //             p1_hp <= p1_hp - (p2_kick_val * kick_mul);
    //             p2_kick_lock <= 1;
    //         end

    //         if (!p1_punch_valid) p1_punch_lock <= 0;    // Reset lock
    //         if (!p2_punch_valid) p2_punch_lock <= 0;    // Reset lock
    //         if (!p1_kick_valid) p1_kick_lock <= 0;    // Reset lock
    //         if (!p2_kick_valid) p2_kick_lock <= 0;    // Reset lock
    //     end
    // end

endmodule