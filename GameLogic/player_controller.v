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
   input wire [3:0] H_speed,
   input wire       powerUp_cmd,
   input wire [5:0] powerUp_val,   // assume the highest value is 25
  
   // --- 2. INCOMING COMBAT (From Referee & Opponent) ---
   input wire       take_hit_pulse,
   input wire [6:0] incoming_damage_val,
   input wire [9:0] opponent_x, // Where is the other player's sprite box?


   input wire match_over,
   input wire i_won,     
  
   // --- 3. PHYSICAL STATE (To Referee & Game Engine) ---
   input wire [9:0] pos_x,
   input wire [9:0] pos_y,
   output reg       facing_right,
   output reg [6:0] hp,
  
   // --- 4. OUTGOING COMBAT (To Referee & Opponent) ---
   output wire       is_punching,        
   output wire       is_dead,
   output wire [6:0] outgoing_damage_val, 
   output reg [3:0]  sprite_state,


   output reg     is_move_left,
   output reg     is_move_right,
   output reg     is_jumping,
   input wire     player // 0 for P1, 1 for P2
);


   // ========================================================================
   // 1. CONSTANTS & PARAMETERS
   // ========================================================================
   localparam MAX_WIDTH = 10'd160;
   localparam GROUND_Y = 10'd110;
   localparam GRAVITY = -10;
   localparam punch_mul = 16'd5;
   localparam MIN_DIST = 10'd5; // Pushbox distance between HURTBOX edges
  
   localparam IDLE = 4'd0, MOVING = 4'd1, ATTACK_ACTIVE = 4'd2, CHARGING = 4'd3, HIT_STUN = 4'd4, DEAD = 4'd5, JUMP_PUNCH = 4'd6, JUMP = 4'd7, VICTORY = 4'd8;
   localparam ON_GROUND = 2'd0, JUMPING = 2'd1, FALLING = 2'd2;
  
   reg signed [7:0] V_speed = 30;
   reg [3:0] H_move_state;
   reg [1:0] V_move_state;
   reg [7:0] active_powerup;
   reg [23:0] action_timer;
   localparam STUN_TIME = 24'd25; // 0.5 seconds at 50MHz


   // ========================================================================
   // 2. HURTBOX & BOUNDARY CALCULATIONS
   // ========================================================================
   localparam SPRITE_W = 10'd64;
   localparam SPRITE_H = 10'd53;
  
   // P1 Offsets
   localparam P1_HURTBOX_W = 10'd25;
   localparam P1_OFFSET_X = (SPRITE_W - P1_HURTBOX_W) / 2; // 19
  
   // P2 Offsets
   localparam P2_HURTBOX_W = 10'd22;
   localparam P2_OFFSET_X = (SPRITE_W - P2_HURTBOX_W) / 2; // 21
  
   // Determine exactly which offsets belong to us and which belong to the opponent
   wire [9:0] my_offset_x   = (player == 1'b0) ? P1_OFFSET_X  : P2_OFFSET_X;
   wire [9:0] my_hurtbox_w  = (player == 1'b0) ? P1_HURTBOX_W : P2_HURTBOX_W;
  
   wire [9:0] opp_offset_x  = (player == 1'b0) ? P2_OFFSET_X  : P1_OFFSET_X;
   wire [9:0] opp_hurtbox_w = (player == 1'b0) ? P2_HURTBOX_W : P1_HURTBOX_W;
  
   // Calculate the actual left and right boundaries of both physical bodies
   wire [9:0] my_hurtbox_left   = pos_x + my_offset_x;
   wire [9:0] my_hurtbox_right  = my_hurtbox_left + my_hurtbox_w;
  
   wire [9:0] opp_hurtbox_left  = opponent_x + opp_offset_x;
   wire [9:0] opp_hurtbox_right = opp_hurtbox_left + opp_hurtbox_w;


   // ========================================================================
   // 3. HORIZONTAL STATE MACHINE
   // ========================================================================
   always @(posedge clk) begin
       if (reset) begin
           H_move_state <= IDLE;
           is_move_right <= 0;
           is_move_left <= 0;
           hp <= 50;
           action_timer <= 0;
           facing_right <= START_FACING;
           active_powerup <= 0;
       end
       else if (match_over) begin
           if (i_won) H_move_state <= VICTORY;
           else if (hp == 0) H_move_state <= DEAD;   
           else H_move_state <= IDLE;   
       end
       else if (play_en) begin
           // Hit Stun Priority
           if (take_hit_pulse && (H_move_state != HIT_STUN)) begin
               if (hp < incoming_damage_val) begin
                   hp <= 0;
                   H_move_state <= DEAD;
               end else begin
                   hp <= hp - incoming_damage_val;
                   H_move_state <= HIT_STUN;  
                   action_timer <= STUN_TIME; 
               end
           end
           // Normal Game Logic
           else begin
               case (H_move_state)
                   IDLE: begin
                       is_move_right <= 0;
                       is_move_left <= 0;
                      
                       if (punch_cmd) begin
                           H_move_state <= ATTACK_ACTIVE;
                           action_timer <= STUN_TIME;
                       end
                       else if (h_move_cmd != 2'b00 && V_move_state == ON_GROUND) H_move_state <= MOVING;
                       else if (powerUp_cmd && V_move_state == ON_GROUND)  H_move_state <= CHARGING;
                   end


                   MOVING: begin
                        is_move_right <= 0;
                        is_move_left <= 0;

                        // Going Right
                        if (h_move_cmd == 2'b01) begin
                            // 1. First check if we have hit the wall
                            if (my_hurtbox_right + H_speed < MAX_WIDTH) begin
                                
                                // 2. Next, check if we are hitting the opponent
                                if ((opp_hurtbox_left > my_hurtbox_left) && (my_hurtbox_right + H_speed + MIN_DIST > opp_hurtbox_left)) begin
                                    H_move_state <= IDLE; // TOO CLOSE: Blocked by opponent pushbox
                                end else begin
                                    facing_right <= 1;
                                    is_move_right <= 1;   // SAFE: Move forward
                                end
                                
                            end else begin
                                H_move_state <= IDLE; // TOO CLOSE: Blocked by right wall
                            end
                        end
                        
                        // Going Left
                        else if (h_move_cmd == 2'b10) begin
                            // 1. First check if we have hit the wall
                            if (my_hurtbox_left > H_speed) begin
                                
                                // 2. Next, check if we are hitting the opponent
                                if ((my_hurtbox_left > opp_hurtbox_left) && (opp_hurtbox_right + H_speed + MIN_DIST > my_hurtbox_left)) begin
                                    H_move_state <= IDLE; // TOO CLOSE: Blocked by opponent pushbox
                                end else begin
                                    facing_right <= 0;
                                    is_move_left <= 1;    // SAFE: Move forward
                                end
                                
                            end else begin
                                H_move_state <= IDLE; // TOO CLOSE: Blocked by left wall
                            end
                        end
                        
                        // Stopped pressing move buttons
                        else if (h_move_cmd == 2'b00) begin
                            H_move_state <= IDLE;
                        end
                    end


                   ATTACK_ACTIVE: begin
                       if (action_timer > 0) begin
                           action_timer <= action_timer - 1;
                       end else begin
                           active_powerup <= 0;
                           H_move_state <= IDLE;
                       end
                   end


                   CHARGING: begin
                       if (!powerUp_cmd) begin
                           H_move_state <= IDLE;
                           active_powerup <= powerUp_val;
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


   // ========================================================================
   // 4. VERTICAL STATE MACHINE (Unchanged)
   // ========================================================================
   always @(posedge clk) begin
       if (reset) begin
           V_move_state <= ON_GROUND;
           // V_speed <= 0;
           is_jumping <= 0;
       end else begin
           case (V_move_state)
               ON_GROUND: begin
                   is_jumping <= 0;
                   if (jump_cmd && play_en) begin
                       V_move_state <= JUMPING;
                   end
               end
               JUMPING, FALLING: begin
                   is_jumping <= 1;
                   if (pos_y >= GROUND_Y) V_move_state <= ON_GROUND;
               end
           endcase
       end
   end


   // ========================================================================
   // 5. SPRITE & OUTPUT ASSIGNMENTS
   // ========================================================================
    parameter S_IDLE = 0, S_WALK = 1, S_PUNCH = 2, S_JUMP = 3; 
    parameter S_JUMP_PUNCH = 4, S_GOT_HIT = 5, S_LOSE = 6, S_WIN = 7;
    always @(*) begin
        if (H_move_state == DEAD)   sprite_state = S_LOSE;
        else if (H_move_state == IDLE || H_move_state == CHARGING)   sprite_state = S_IDLE;
        else if (H_move_state == MOVING)   sprite_state = S_WALK;
        else if (V_move_state == JUMPING || V_move_state == FALLING) begin
            if (H_move_state == ATTACK_ACTIVE)
                sprite_state = S_JUMP_PUNCH;
            else
                sprite_state = S_JUMP;
        end
        else if (H_move_state == HIT_STUN) sprite_state = S_GOT_HIT;
        else if (H_move_state == VICTORY)   sprite_state = S_VICTORY;
        // Default catch
        else sprite_state = S_IDLE;
    end


    assign is_punching = (H_move_state == ATTACK_ACTIVE);
    assign is_dead     = (H_move_state == DEAD);
    
    assign outgoing_damage_val = (H_move_state == ATTACK_ACTIVE) ?
        ((active_powerup > 0) ? ({3'b000, punch_val} * punch_mul * active_powerup) / 10 : ({3'b000, punch_val} * punch_mul))
        : 7'd0; 


   // hp 0 to 50
   // muscle 0 to 25


endmodule

