// // module player_controller(
// //     input wire clk,
// //     input wire reset,
// //     // Control inputs from SPI
// //     input wire [1:0] h_move_cmd,
// //     input wire jump_cmd,
// //     input wire punch_cmd,
// //     input wire [2:0] punch_val,
// //     input wire kick_cmd,
// //     input wire [2:0] kick_val,
// //     input wire [3:0] H_speed,
// //     input wire [3:0] V_speed,
// //     input wire powerUp_cmd,
// //     input wire [2:0] powerUp_val,
// //     // Enemy data for collision
// //     input wire [9:0] enemy_x, enemy_y,
// //     input wire p1_hit_p2_upper, p1_hit_p2_lower, p2_hit_p1_upper, p2_hit_p1_lower,
// //     input wire [4:0] incoming_damage_val,
// //     // Outputs
// //     output reg [9:0] pos_x, pos_y,
// //     output reg [6:0] hp,
// //     output wire [4:0] deal_damage_out // Signal to the referee that we hit someone
// // );
// module player_controller#(
//     parameter START_X = 10'd100,      // Default start position
//     parameter START_FACING = 1'b1     // 1 for right, 0 for left
// )(
//     input wire clk,
//     input wire reset,
    
//     // --- 1. USER INTENT (From SPI) ---
//     input wire [1:0] h_move_cmd,
//     input wire       jump_cmd,
//     input wire       punch_cmd,
//     input wire [3:0] punch_val,
//     // input wire       kick_cmd,
//     // input wire [2:0] kick_val,
//     input wire [3:0] H_speed,
//     // input wire [3:0] V_speed,
//     input wire       powerUp_cmd,
//     input wire [5:0] powerUp_val,
    
//     // --- 2. INCOMING COMBAT (From Referee & Opponent) ---
//     // We replace all specific p1/p2 signals with a generic "I got hit" pulse
//     input wire       take_hit_pulse, 
//     input wire [4:0] incoming_damage_val,
    
//     // --- 3. PHYSICAL STATE (To Referee & Game Engine) ---
//     output reg [9:0] pos_x, 
//     output reg [9:0] pos_y,
//     output reg       facing_right, // The referee needs to know which way we are looking!
//     output reg [6:0] hp,
    
//     // --- 4. OUTGOING COMBAT (To Referee & Opponent) ---
//     output wire       is_punching,         // Tells referee to turn on the upper hitbox
//     output wire       is_dead,
//     // output wire       is_kicking,          // Tells referee to turn on the lower hitbox
//     output reg [6:0] outgoing_damage_val,  // The damage we will deal IF the referee says it hits
//     output reg [2:0] sprite_state
// );
//     // character movements
//     localparam MAX_WIDTH = 640;
//     localparam GROUND_Y = 400;
//     localparam GRAVITY = -10;
//     localparam punch_mul = 10;
//     // localparam kick_mul = 15;
//     reg signed [7:0] V_speed = 30;
//     // typedef enum {ON_GROUND, JUMPING, FALLING} state_vertical;
//     // typedef enum {IDLE, MOVING, ATTACK_ACTIVE, CHARGING, HIT_STUN} state_horizontal; // do we need like a stun phase?
//     localparam IDLE = 3'd0, MOVING = 3'd1, ATTACK_ACTIVE = 3'd2, CHARGING = 3'd3, HIT_STUN = 3'd4, DEAD = 3'd5, JUMP_PUNCH = 3'd6, JUMP = 3'd7;
//     reg [2:0] H_move_state;

//     localparam ON_GROUND = 2'd0, JUMPING = 2'd1, FALLING = 2'd2;
//     reg [1:0] V_move_state;
//     // state_vertical V_move_state;
//     // state_horizontal H_move_state;

//     // p1 movements


//     reg [23:0] action_timer; 
//     localparam STUN_TIME = 24'd25_000_000; // 0.5 seconds at 50MHz
//     // horizontal (left right, punches, kicks, charge ups)
//     always @(posedge clk) begin
//         if (reset) begin
//             H_move_state <= IDLE;
//             hp <= 125;
//             pos_x <= START_X;
//             action_timer <= 0;
//             facing_right <= START_FACING;
//         end

//         // Getting hit with hit stun has the second highest priority
//         else if (take_hit_pulse && (H_move_state != HIT_STUN)) begin
//             if (hp < incoming_damage_val) begin
//                 H_move_state <= DEAD;
//             end
//             else begin
//                 hp <= hp - incoming_damage_val; // taking damage
//                 H_move_state <= HIT_STUN;   // transition to hit stun state
//                 action_timer <= STUN_TIME;  // start the stun timer count down
//             end
//         end

//         // Normal Game Logic
//         else begin
//             case (H_move_state)
//                 IDLE: begin
//                     // if (punch_cmd || kick_cmd) begin
//                     if (punch_cmd) begin
//                         H_move_state <= ATTACK_ACTIVE;
//                         action_timer <= STUN_TIME;
//                     end
//                     else if (h_move_cmd != 2'b00) H_move_state <= MOVING;
//                     else if (powerUp_cmd)  H_move_state <= CHARGING;
//                 end

//                 MOVING: begin
//                     // going right
//                     if (h_move_cmd == 2'b01) begin
//                         if (pos_x + H_speed < MAX_WIDTH) begin
//                             pos_x <= pos_x + H_speed;
//                             facing_right <= 1;
//                         end
//                         else    H_move_state <= IDLE;
//                     end
//                     // going left
//                     else if (h_move_cmd == 2'b10) begin
//                         if (pos_x > H_speed) begin
//                             pos_x <= pos_x - H_speed;
//                             facing_right <= 0;
//                         end
//                         else    H_move_state <= IDLE;
//                     end

//                     if (h_move_cmd == 2'b00) H_move_state <= IDLE;
//                     // if (punch_cmd || kick_cmd) begin
//                     if (punch_cmd) begin
//                         H_move_state <= ATTACK_ACTIVE;
//                         action_timer <= STUN_TIME;
//                     end
//                     if (powerUp_cmd) H_move_state <= CHARGING;
//                 end

//                 ATTACK_ACTIVE: begin
//                     if (action_timer > 0) begin
//                         action_timer <= action_timer - 1;

//                         if (punch_cmd)  outgoing_damage_val <= (punch_val * punch_mul * powerUp_val) / 10;
//                         // else if (kick_cmd)  outgoing_damage_val <= kick_val * kick_mul * powerUp_val;
//                     end else begin
//                         outgoing_damage_val <= 0;
//                         if (h_move_cmd != 2'b00) H_move_state <= MOVING;
//                         else H_move_state <= IDLE;
//                         if (powerUp_cmd) H_move_state <= CHARGING;
//                     end
//                 end

//                 CHARGING: begin
//                     if (!powerUp_cmd) begin
//                         H_move_state <= IDLE;
//                     end
//                 end

//                 HIT_STUN: begin
//                     if (action_timer > 0) begin
//                         action_timer <= action_timer - 1;
//                     end else begin
//                         H_move_state <= IDLE;
//                     end
//                 end

//                 DEAD: begin
//                 end
//             endcase
//         end
//     end

//     // vertical movements (mainly jumping)
//     always @(posedge clk) begin
//         if (reset) begin
//             V_move_state <= ON_GROUND;
//             pos_y <= GROUND_Y;
//             V_speed <= 0;
//         end else begin
//             case (V_move_state)
//                 ON_GROUND: begin
//                     pos_y <= GROUND_Y;
//                     V_speed <= 0;
//                     if (jump_cmd) begin
//                         V_move_state <= JUMPING;
//                         V_speed <= 40;
//                     end
//                 end
//                 JUMPING, FALLING: begin
//                     pos_y <= pos_y - V_speed;   // Update position
//                     V_speed <= V_speed + GRAVITY; // Apply gravity
//                     if (pos_y <= GROUND_Y) V_move_state <= ON_GROUND;
//                 end
//             endcase
//         end
//     end

//     // Sprite Updates
//     localparam SPRITE_IDLE_R      = 4'd0;
//     localparam SPRITE_IDLE_L      = 4'd1;
//     localparam SPRITE_WALK_R      = 4'd2;
//     localparam SPRITE_WALK_L      = 4'd3;
//     localparam SPRITE_JUMP_R      = 4'd4;
//     localparam SPRITE_JUMP_L      = 4'd5;
//     localparam SPRITE_PUNCH_R     = 4'd6;
//     localparam SPRITE_PUNCH_L     = 4'd7;
//     localparam SPRITE_JUMP_PUNCH_R= 4'd8;
//     localparam SPRITE_JUMP_PUNCH_L= 4'd9;
//     localparam SPRITE_HIT_STUN_R  = 4'd10;
//     localparam SPRITE_HIT_STUN_L  = 4'd11;
//     localparam SPRITE_KO_R        = 4'd12;
//     localparam SPRITE_KO_L        = 4'd13;

//     reg [3:0] current_sprite;
//     assign sprite_id = current_sprite;

//     always @(*) begin
//         // Dead
//         // if (H_move_state == DEAD) begin
//         //     current_sprite = facing_right ? SPRITE_KO_R : SPRITE_KO_L;
//         // end
//         // // Gettinng Hit
//         // else if (H_move_state == HIT_STUN) begin
//         //     current_sprite = facing_right ? SPRITE_HIT_STUN_R : SPRITE_HIT_STUN_L;
//         // end
//         // // In the Air
//         // else if (V_move_state == JUMPING || V_move_state == FALLING) begin
//         //     if (H_move_state == ATTACK_ACTIVE)
//         //         current_sprite = facing_right ? SPRITE_JUMP_PUNCH_R : SPRITE_JUMP_PUNCH_L;
//         //     else
//         //         current_sprite = facing_right ? SPRITE_JUMP_R : SPRITE_JUMP_L;
//         // end
//         // // Ground Attacks
//         // else if (H_move_state == ATTACK_ACTIVE) begin
//         //     current_sprite = facing_right ? SPRITE_PUNCH_R : SPRITE_PUNCH_L;
//         // end
//         // // Moving
//         // else if (H_move_state == MOVING) begin
//         //     current_sprite = facing_right ? SPRITE_WALK_R : SPRITE_WALK_L;
//         // end
//         // // Idle
//         // else begin
//         //     current_sprite = facing_right ? SPRITE_IDLE_R : SPRITE_IDLE_L;
//         // end
//         if (H_move_state == DEAD)   sprite_state = DEAD;
//         else if (H_move_state == IDLE)   sprite_state = IDLE;
//         else if (H_move_state == MOVING)   sprite_state = MOVING;
//         else if (V_move_state == JUMPING || V_move_state == FALLING) begin
//             if (H_move_state == ATTACK_ACTIVE)
//                 sprite_state = JUMP_PUNCH;
//             else
//                 sprite_state = JUMP;
//         end
//         else if (H_move_state == CHARGING)  sprite_state = CHARGING;
//     end

//     assign is_punching = (H_move_state == ATTACK_ACTIVE) && punch_cmd;
//     assign is_dead     = (H_move_state == DEAD);
//     // assign is_kicking  = (H_move_state == ATTACK_ACTIVE) && kick_cmd;
// endmodule

module player_controller#(
    parameter START_X = 10'd100,      // Default start position
    parameter START_FACING = 1'b1     // 1 for right, 0 for left
)(
    input wire clk,
    input wire reset,
    input wire play_en,
    
    // --- 1. USER INTENT (From SPI) ---
    input wire [1:0] h_move_cmd,
    input wire       jump_cmd,
    input wire       punch_cmd,
    input wire [3:0] punch_val,
    // input wire       kick_cmd,
    // input wire [2:0] kick_val,
    input wire [3:0] H_speed,
    // input wire [3:0] V_speed,
    input wire       powerUp_cmd,
    input wire [5:0] powerUp_val,
    
    // --- 2. INCOMING COMBAT (From Referee & Opponent) ---
    // We replace all specific p1/p2 signals with a generic "I got hit" pulse
    input wire       take_hit_pulse, 
    input wire [6:0] incoming_damage_val,
    input wire [9:0] opponent_x, // ADDED: Where is the other player?

    input wire match_over, // ADDED: Tells the player the game has ended
    input wire i_won,      // ADDED: High if this specific player is the winner
    
    // --- 3. PHYSICAL STATE (To Referee & Game Engine) ---
    output reg [9:0] pos_x, 
    output reg [9:0] pos_y,
    output reg       facing_right, // The referee needs to know which way we are looking!
    output reg [6:0] hp,
    
    // --- 4. OUTGOING COMBAT (To Referee & Opponent) ---
    output wire       is_punching,         // Tells referee to turn on the upper hitbox
    output wire       is_dead,
    // output wire       is_kicking,          // Tells referee to turn on the lower hitbox
    output wire [6:0] outgoing_damage_val,  // The damage we will deal IF the referee says it hits
    output reg [3:0] sprite_state
);
    // character movements
    localparam MAX_WIDTH = 640;
    localparam GROUND_Y = 400;
    localparam GRAVITY = -10;
    localparam punch_mul = 16'd10;
    localparam MIN_DIST = 10'd40; // ADDED: Minimum pixels between players (The Pushbox)
    // localparam kick_mul = 15;
    reg signed [7:0] V_speed = 30;
    // typedef enum {ON_GROUND, JUMPING, FALLING} state_vertical;
    // typedef enum {IDLE, MOVING, ATTACK_ACTIVE, CHARGING, HIT_STUN} state_horizontal; // do we need like a stun phase?
    localparam IDLE = 4'd0, MOVING = 4'd1, ATTACK_ACTIVE = 4'd2, CHARGING = 4'd3, HIT_STUN = 4'd4, DEAD = 4'd5, JUMP_PUNCH = 4'd6, JUMP = 4'd7, VICTORY = 4'd8;
    reg [3:0] H_move_state;

    localparam ON_GROUND = 2'd0, JUMPING = 2'd1, FALLING = 2'd2;
    reg [1:0] V_move_state;
	 reg [7:0] active_powerup;
    // state_vertical V_move_state;
    // state_horizontal H_move_state;

    // p1 movements


    reg [23:0] action_timer; 
    localparam STUN_TIME = 24'd25_000_000; // 0.5 seconds at 50MHz
    // horizontal (left right, punches, kicks, charge ups)
    always @(posedge clk) begin
        if (reset) begin
            H_move_state <= IDLE;
            hp <= 125;
            pos_x <= START_X;
            action_timer <= 0;
            facing_right <= START_FACING;
				active_powerup <= 0;
        end

        else if (match_over) begin
            if (i_won) begin
                H_move_state <= VICTORY; // You won! Do a victory pose.
            end 
            else if (hp == 0) begin
                H_move_state <= DEAD;    // You got knocked out.
            end 
            else begin
                H_move_state <= IDLE;    // You lost by timeout (or draw), just stand there in shame.
            end
        end

        // Getting hit with hit stun has the second highest priority
        else if (play_en) begin
            if (take_hit_pulse && (H_move_state != HIT_STUN)) begin
                if (hp < incoming_damage_val) begin
                        hp <= 0;
                    H_move_state <= DEAD;
                end
                else begin
                    hp <= hp - incoming_damage_val; // taking damage
                    H_move_state <= HIT_STUN;   // transition to hit stun state
                    action_timer <= STUN_TIME;  // start the stun timer count down
                end
            end

            // Normal Game Logic
            else begin
                case (H_move_state)
                    IDLE: begin
                        // if (punch_cmd || kick_cmd) begin
                        if (punch_cmd) begin
                            H_move_state <= ATTACK_ACTIVE;
                            action_timer <= STUN_TIME;
                        end
                        else if (h_move_cmd != 2'b00 && V_move_state == ON_GROUND) H_move_state <= MOVING;
                        else if (powerUp_cmd && V_move_state == ON_GROUND)  H_move_state <= CHARGING;
                            //outgoing_damage_val <= 7'd15; // LOAD DAMAGE INSTANTLY HERE TOO
                    end

                    MOVING: begin
                        // going right
                        if ((pos_x + H_speed < MAX_WIDTH) && 
                                (!(opponent_x > pos_x) || (opponent_x - pos_x > MIN_DIST))) begin
                                pos_x <= pos_x + H_speed;
                                facing_right <= 1;
                            end
                            else H_move_state <= IDLE; // Blocked by wall or opponent
                        end
                        // going left
                        else if (h_move_cmd == 2'b10) begin
                            // Check screen edge AND pushbox distance
                            if ((pos_x > H_speed) && 
                                (!(pos_x > opponent_x) || (pos_x - opponent_x > MIN_DIST))) begin
                                pos_x <= pos_x - H_speed;
                                facing_right <= 0;
                            end
                            else H_move_state <= IDLE; // Blocked by wall or opponent
                        end

                        if (h_move_cmd == 2'b00) H_move_state <= IDLE;
                        // if (punch_cmd || kick_cmd) begin
                        // if (punch_cmd) begin
                        //     H_move_state <= ATTACK_ACTIVE;
                        //     action_timer <= STUN_TIME;
                        // end
                        // if (powerUp_cmd) H_move_state <= CHARGING;
                        // H_move_state <= IDLE;
                    end

                    ATTACK_ACTIVE: begin
                        if (action_timer > 0) begin
                            action_timer <= action_timer - 1;

                            //if (punch_cmd) begin
                                    //	if (powerUp_val == 1) begin
                                    //			outgoing_damage_val <= (punch_val * punch_mul);
                                    //	end else begin
                                    //		outgoing_damage_val <= (punch_val * punch_mul * powerUp_val) / 10;
                                    //	end
                                    //end
                            // else if (kick_cmd)  outgoing_damage_val <= kick_val * kick_mul * powerUp_val;
                        end else begin
                            //outgoing_damage_val <= 0;
                                    active_powerup <= 0;
                            // if (h_move_cmd != 2'b00) H_move_state <= MOVING;
                            // else H_move_state <= IDLE;
                            // if (powerUp_cmd) H_move_state <= CHARGING;
                            H_move_state <= IDLE;
                        end
                    end

                    CHARGING: begin
                        if (!powerUp_cmd) begin
                            H_move_state <= IDLE;
                            active_powerup <= powerUp_val; // SAVE THE SWITCH VALUE!
                        end
                    end

                    HIT_STUN: begin
                        if (action_timer > 0) begin
                            action_timer <= action_timer - 1;
                        end else begin
                            H_move_state <= IDLE;
                        end
                    end

                    DEAD: begin
                    end
                endcase
            end
        end
    end

    // vertical movements (mainly jumping)
    always @(posedge clk) begin
        if (reset) begin
            V_move_state <= ON_GROUND;
            pos_y <= GROUND_Y;
            V_speed <= 0;
        end else begin
            case (V_move_state)
                ON_GROUND: begin
                    pos_y <= GROUND_Y;
                    V_speed <= 0;
                    if (jump_cmd && play_en) begin
                        V_move_state <= JUMPING;
                        V_speed <= 40;
                    end
                end
                JUMPING, FALLING: begin
                    pos_y <= pos_y - V_speed;   // Update position
                    V_speed <= V_speed + GRAVITY; // Apply gravity
                    if (pos_y <= GROUND_Y) V_move_state <= ON_GROUND;
                end
            endcase
        end
    end

    // Sprite Updates
    localparam SPRITE_IDLE_R      = 4'd0;
    localparam SPRITE_IDLE_L      = 4'd1;
    localparam SPRITE_WALK_R      = 4'd2;
    localparam SPRITE_WALK_L      = 4'd3;
    localparam SPRITE_JUMP_R      = 4'd4;
    localparam SPRITE_JUMP_L      = 4'd5;
    localparam SPRITE_PUNCH_R     = 4'd6;
    localparam SPRITE_PUNCH_L     = 4'd7;
    localparam SPRITE_JUMP_PUNCH_R= 4'd8;
    localparam SPRITE_JUMP_PUNCH_L= 4'd9;
    localparam SPRITE_HIT_STUN_R  = 4'd10;
    localparam SPRITE_HIT_STUN_L  = 4'd11;
    localparam SPRITE_KO_R        = 4'd12;
    localparam SPRITE_KO_L        = 4'd13;

    reg [3:0] current_sprite;
    assign sprite_id = current_sprite;

    always @(*) begin
        // Dead
        // if (H_move_state == DEAD) begin
        //     current_sprite = facing_right ? SPRITE_KO_R : SPRITE_KO_L;
        // end
        // // Gettinng Hit
        // else if (H_move_state == HIT_STUN) begin
        //     current_sprite = facing_right ? SPRITE_HIT_STUN_R : SPRITE_HIT_STUN_L;
        // end
        // // In the Air
        // else if (V_move_state == JUMPING || V_move_state == FALLING) begin
        //     if (H_move_state == ATTACK_ACTIVE)
        //         current_sprite = facing_right ? SPRITE_JUMP_PUNCH_R : SPRITE_JUMP_PUNCH_L;
        //     else
        //         current_sprite = facing_right ? SPRITE_JUMP_R : SPRITE_JUMP_L;
        // end
        // // Ground Attacks
        // else if (H_move_state == ATTACK_ACTIVE) begin
        //     current_sprite = facing_right ? SPRITE_PUNCH_R : SPRITE_PUNCH_L;
        // end
        // // Moving
        // else if (H_move_state == MOVING) begin
        //     current_sprite = facing_right ? SPRITE_WALK_R : SPRITE_WALK_L;
        // end
        // // Idle
        // else begin
        //     current_sprite = facing_right ? SPRITE_IDLE_R : SPRITE_IDLE_L;
        // end
        if (H_move_state == DEAD)   sprite_state = DEAD;
        else if (H_move_state == IDLE)   sprite_state = IDLE;
        else if (H_move_state == MOVING)   sprite_state = MOVING;
        else if (V_move_state == JUMPING || V_move_state == FALLING) begin
            if (H_move_state == ATTACK_ACTIVE)
                sprite_state = JUMP_PUNCH;
            else
                sprite_state = JUMP;
        end
        else if (H_move_state == CHARGING)  sprite_state = CHARGING;
        else if (H_move_state == VICTORY)   sprite_state = VICTORY;
    end

    //assign is_punching = (H_move_state == ATTACK_ACTIVE) && punch_cmd;
	 assign is_punching = (H_move_state == ATTACK_ACTIVE);
    assign is_dead     = (H_move_state == DEAD);
	 // If powerUp is active (greater than 0), multiply by powerUp. 
    // If powerUp is 0, just deal normal damage.
    assign outgoing_damage_val = (H_move_state == ATTACK_ACTIVE) ? 
        ((active_powerup > 0) ? ({3'b000, punch_val} * punch_mul * active_powerup) / 10 : ({3'b000, punch_val} * punch_mul)) 
        : 7'd0;  
	// assign is_kicking  = (H_move_state == ATTACK_ACTIVE) && kick_cmd;
endmodule

