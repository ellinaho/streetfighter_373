// module player_controller(
//     input wire clk,
//     input wire reset,
//     // Control inputs from SPI
//     input wire [1:0] h_move_cmd,
//     input wire jump_cmd,
//     input wire punch_cmd,
//     input wire [2:0] punch_val,
//     input wire kick_cmd,
//     input wire [2:0] kick_val,
//     input wire [3:0] H_speed,
//     input wire [3:0] V_speed,
//     input wire powerUp_cmd,
//     input wire [2:0] powerUp_val,
//     // Enemy data for collision
//     input wire [9:0] enemy_x, enemy_y,
//     input wire p1_hit_p2_upper, p1_hit_p2_lower, p2_hit_p1_upper, p2_hit_p1_lower,
//     input wire [4:0] incoming_damage_val,
//     // Outputs
//     output reg [9:0] pos_x, pos_y,
//     output reg [6:0] hp,
//     output wire [4:0] deal_damage_out // Signal to the referee that we hit someone
// );
module player_controller#(
    parameter START_X = 10'd100,      // Default start position
    parameter START_FACING = 1'b1     // 1 for right, 0 for left
)(
    input wire clk,
    input wire reset,
    
    // --- 1. USER INTENT (From SPI) ---
    input wire [1:0] h_move_cmd,
    input wire       jump_cmd,
    input wire       punch_cmd,
    input wire [2:0] punch_val,
    input wire       kick_cmd,
    input wire [2:0] kick_val,
    input wire [3:0] H_speed,
    // input wire [3:0] V_speed,
    input wire       powerUp_cmd,
    input wire [2:0] powerUp_val,
    
    // --- 2. INCOMING COMBAT (From Referee & Opponent) ---
    // We replace all specific p1/p2 signals with a generic "I got hit" pulse
    input wire       take_hit_pulse, 
    input wire [4:0] incoming_damage_val,
    
    // --- 3. PHYSICAL STATE (To Referee & Game Engine) ---
    output reg [9:0] pos_x, 
    output reg [9:0] pos_y,
    output reg       facing_right, // The referee needs to know which way we are looking!
    output reg [6:0] hp,
    
    // --- 4. OUTGOING COMBAT (To Referee & Opponent) ---
    output wire       is_punching,         // Tells referee to turn on the upper hitbox
    output wire       is_kicking,          // Tells referee to turn on the lower hitbox
    output reg [4:0] outgoing_damage_val  // The damage we will deal IF the referee says it hits
);
    // character movements
    localparam MAX_WIDTH = 640;
    localparam GROUND_Y = 400;
    localparam GRAVITY = -10;
    localparam punch_mul = 10;
    localparam kick_mul = 15;
    reg signed [7:0] V_speed = 30;
    // typedef enum {ON_GROUND, JUMPING, FALLING} state_vertical;
    // typedef enum {IDLE, MOVING, ATTACK_ACTIVE, CHARGING, HIT_STUN} state_horizontal; // do we need like a stun phase?
    localparam IDLE = 3'd0, MOVING = 3'd1, ATTACK_ACTIVE = 3'd2, CHARGING = 3'd3, HIT_STUN = 3'd4;
    reg [2:0] H_move_state;

    localparam ON_GROUND = 2'd0, JUMPING = 2'd1, FALLING = 2'd2;
    reg [1:0] V_move_state;
    // state_vertical V_move_state;
    // state_horizontal H_move_state;

    wire collision;
     // defining hitbox, how close characters must be to hit each other
    // assign collision = (pos_x < enemy_x + 20) && (pos_x + 20 > enemy_x) && (pos_y < enemy_y + 20) && (pos_y + 20 > enemy_y);

    // p1 movements


    reg [23:0] action_timer; 
    localparam STUN_TIME = 24'd25_000_000; // 0.5 seconds at 50MHz
    // horizontal (left right, punches, kicks, charge ups)
    always @(posedge clk) begin
        if (reset) begin
            H_move_state <= IDLE;
            hp <= 100;
            pos_x <= START_X;
            action_timer <= 0;
            facing_right <= START_FACING;
        end

        // Getting hit with hit stun has the second highest priority
        else if (take_hit_pulse && (H_move_state != HIT_STUN)) begin
            hp <= hp - incoming_damage_val; // taking damage
            H_move_state <= HIT_STUN;   // transition to hit stun state
            action_timer <= STUN_TIME;  // start the stun timer count down
        end

        // Normal Game Logic
        else begin
            case (H_move_state)
                IDLE: begin
                    if (punch_cmd || kick_cmd) begin
                        H_move_state <= ATTACK_ACTIVE;
                        action_timer <= STUN_TIME;
                    end
                    else if (h_move_cmd != 2'b00) H_move_state <= MOVING;
                    else if (powerUp_cmd)  H_move_state <= CHARGING;
                end

                MOVING: begin
                    // going right
                    if (h_move_cmd == 2'b01) begin
                        if (pos_x + H_speed < MAX_WIDTH) begin
                            pos_x <= pos_x + H_speed;
                            facing_right <= 1;
                        end
                        else    H_move_state <= IDLE;
                    end
                    // going left
                    else if (h_move_cmd == 2'b10) begin
                        if (pos_x > H_speed) begin
                            pos_x <= pos_x - H_speed;
                            facing_right <= 0;
                        end
                        else    H_move_state <= IDLE;
                    end

                    if (h_move_cmd == 2'b00) H_move_state <= IDLE;
                    if (punch_cmd || kick_cmd) begin
                        H_move_state <= ATTACK_ACTIVE;
                        action_timer <= STUN_TIME;
                    end
                    if (powerUp_cmd) H_move_state <= CHARGING;
                end

                ATTACK_ACTIVE: begin
                    // if (punch_cmd && collision && !p1_punch_lock) begin
                    //     p2_hp <= p2_hp - (punch_val * punch_mul * powerUp_val);
                    //     p1_punch_lock <= 1;
                    //     powerUp_val <= 1;
                    // end
                    // else if (kick_cmd && collision && !p1_kick_lock) begin
                    //     p2_hp <= p2_hp - (kick_val * kick_mul);
                    //     p1_kick_lock <= 1;
                    // end

                    // if (!punch_cmd) p1_punch_lock <= 0;    // Reset lock
                    // if (!kick_cmd) p1_kick_lock <= 0;    // Reset lock

                    if (action_timer > 0) begin
                        action_timer <= action_timer - 1;

                        if (punch_cmd)  outgoing_damage_val <= punch_val * punch_mul * powerUp_val;
                        else if (kick_cmd)  outgoing_damage_val <= kick_val * kick_mul * powerUp_val;
                    end else begin
                        outgoing_damage_val <= 0;
                        if (h_move_cmd != 0'b00) H_move_state <= MOVING;
                        else H_move_state <= IDLE;
                        if (powerUp_cmd) H_move_state <= CHARGING;
                    end
                end

                CHARGING: begin
                    if (!powerUp_cmd) begin
                        H_move_state <= IDLE;
                    end
                end

                HIT_STUN: begin
                    if (action_timer > 0) begin
                        action_timer <= action_timer - 1;
                    end else begin
                        H_move_state <= IDLE;
                    end
                end
            endcase
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
                    if (jump_cmd) begin
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

    assign is_punching = (H_move_state == ATTACK_ACTIVE) && punch_cmd;
    assign is_kicking  = (H_move_state == ATTACK_ACTIVE) && kick_cmd;
endmodule