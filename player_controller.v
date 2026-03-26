module player_controller(
    input wire clk,
    input wire reset,
    // Control inputs from SPI
    input wire [1:0] h_move_cmd,
    input wire jump_cmd,
    input wire punch_cmd,
    input wire [2:0] punch_val,
    input wire kick_cmd,
    input wire [2:0] kick_val,
    input wire [3:0] H_speed,
    input wire [3:0] V_speed,
    input wire powerUp_cmd,
    input wire [2:0] powerUp_val,
    // Enemy data for collision
    input wire [9:0] enemy_x, enemy_y,
    // Outputs
    output reg [9:0] pos_x, pos_y,
    output reg [6:0] hp,
    output reg deal_damage_out // Signal to the referee that we hit someone
);

    // character movements

    typedef enum {ON_GROUND, JUMPING, FALLING} state_vertical;
    typedef enum {IDLE, MOVING, ATTACK_ACTIVE, CHARGING, HIT_STUN} state_horizontal; // do we need like a stun phase?
    state_vertical V_move_state;
    state_horizontal H_move_state;

    wire collision;
     // defining hitbox, how close characters must be to hit each other
    assign collision = (pos_x < enemy_x + 20) && (pos_x + 20 > enemy_x) && (pos_y < enemy_y + 20) && (pos_y + 20 > enemy_y);

    // p1 movements

    // horizontal (left right, punches, kicks, charge ups)
    always @(posedge clk) begin
        if (current_state == PLAY) begin
            case (H_move_state)
                IDLE: begin
                    if (punch_cmd) H_move_state <= ATTACK_ACTIVE;
                    else if (h_move_cmd != 2'b00) H_move_state <= MOVING;
                    else if (powerUp_cmd)  H_move_state <= CHARGING;
                end

                MOVING: begin
                    // going right
                    if (h_move_cmd == 2'b01) begin
                        if (pos_x + H_speed < MAX_WIDTH) pos_x <= pos_x + H_speed;
                        else    H_move_state <= IDLE;
                    end
                    // going left
                    else if (h_move_cmd == 2'b10) begin
                        if (pos_x > H_speed)  pos_x <= pos_x - H_speed;
                        else    H_move_state <= IDLE;
                    end

                    if (h_move_cmd == 2'b00) H_move_state <= IDLE;
                    if (punch_cmd) H_move_state <= ATTACK_ACTIVE;
                    if (powerUp_cmd) H_move_state <= CHARGING;
                end

                ATTACK_ACTIVE: begin
                    if (punch_cmd && collision && !p1_punch_lock) begin
                        p2_hp <= p2_hp - (punch_val * punch_mul * powerUp_val);
                        p1_punch_lock <= 1;
                        powerUp_val <= 1;
                    end
                    else if (kick_cmd && collision && !p1_kick_lock) begin
                        p2_hp <= p2_hp - (kick_val * kick_mul);
                        p1_kick_lock <= 1;
                    end

                    if (!punch_cmd) p1_punch_lock <= 0;    // Reset lock
                    if (!kick_cmd) p1_kick_lock <= 0;    // Reset lock

                    if (!punch_cmd && !kick_cmd) begin
                        if (h_move_cmd != 0'b00) H_move_state <= MOVING;
                        else H_move_state <= IDLE;
                    end
                    if (powerUp_cmd) H_move_state <= CHARGING;
                end

                CHARGING: begin
                    if (!powerUp_cmd) begin
                        H_move_state <= IDLE;
                    end
                end
            endcase
        end
    end

    // vertical movements (mainly jumping)
    always @(posedge clk) begin
        if (current_state == PLAY) begin
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
                    pos_y <= pos_y + V_speed;   // Update position
                    V_speed <= V_speed + GRAVITY; // Apply gravity
                    if (pos_y <= GROUND_Y) V_move_state <= ON_GROUND;
                end
            endcase
        end
    end
endmodule