`timescale 1 ns/1 ns

module tb_fighting_game();
    // --- System Clock and Reset ---
    reg CLOCK_50;
    reg rst_n; // Active low reset (KEY[0])

    // --- Inputs to Game Engine ---
    reg p1_start_button;
    reg p2_start_button;
    reg rematch_button_wire;

    // --- Inputs to Player 1 ---
    reg [1:0] p1_h_move;
    reg       p1_jump_cmd;
    reg       p1_punch_cmd;
    reg [3:0] p1_punch_val;
    reg [3:0] p1_H_speed;
    reg       p1_powerUp_cmd;
    reg [5:0] p1_powerUp_val;

    // --- Inputs to Player 2 ---
    reg [1:0] p2_h_move;
    reg       p2_jump_cmd;
    reg       p2_punch_cmd;
    reg [3:0] p2_punch_val;
    reg [3:0] p2_H_speed;
    reg       p2_powerUp_cmd;
    reg [5:0] p2_powerUp_val;

    // --- Wires (Outputs from modules) ---
    wire [6:0] p1_hp, p2_hp;
    wire [2:0] current_game_state;
    wire       start_new_round_wire;
    wire       match_over, p1_winner, p2_winner;

    reg [9:0] p1_x, p1_y, p2_x, p2_y;
    wire       p1_facing_right, p2_facing_right;
    wire       p1_is_punching, p2_is_punching;
    wire       p1_dead, p2_dead;
    wire [6:0] p1_outgoing_damage, p2_outgoing_damage;
    wire [3:0] p1_sprite, p2_sprite;

    wire p1_hit_p2, p2_hit_p1;

    wire     p1_is_move_left, p1_is_move_right, p1_is_jumping;
    wire     p2_is_move_left, p2_is_move_right, p2_is_jumping;

    // --- Module Instantiations ---
    game_engine game(
        .clk(CLOCK_50), .rst(~rst_n),
        .p1_ready(p1_start_button), .p2_ready(p2_start_button), .restart_cmd(rematch_button_wire),
        .p1_hp(p1_hp), .p2_hp(p2_hp),
        .game_state_out(current_game_state), .round_reset(start_new_round_wire),
        .match_over(match_over), .p1_winner(p1_winner), .p2_winner(p2_winner)
    );

    player_controller #(.START_X(10'd30), .START_FACING(1)) p1(
        .clk(CLOCK_50), .reset(start_new_round_wire), .play_en(current_game_state == 3'd1),
        .h_move_cmd(p1_h_move), .jump_cmd(p1_jump_cmd), .punch_cmd(p1_punch_cmd), .punch_val(p1_punch_val),
        .H_speed(p1_H_speed), .powerUp_cmd(p1_powerUp_cmd), .powerUp_val(p1_powerUp_val),
        .take_hit_pulse(p2_hit_p1), .incoming_damage_val(p2_outgoing_damage), .opponent_x(p2_x),
        .pos_x(p1_x), .pos_y(p1_y), .facing_right(p1_facing_right), .hp(p1_hp),
        .is_punching(p1_is_punching), .is_dead(p1_dead), .outgoing_damage_val(p1_outgoing_damage), .sprite_state(p1_sprite),
        .match_over(match_over), .i_won(p1_winner), .is_move_left(p1_is_move_left), .is_move_right(p1_is_move_right), .is_jumping(p1_is_jumping),
        .player(1'b0) // ADDED: Tells module this is Player 1
    );

    // CHANGED START_X to 120 so it fits inside MAX_WIDTH = 160
    player_controller #(.START_X(10'd120), .START_FACING(0)) p2(
        .clk(CLOCK_50), .reset(start_new_round_wire), .play_en(current_game_state == 3'd1),
        .h_move_cmd(p2_h_move), .jump_cmd(p2_jump_cmd), .punch_cmd(p2_punch_cmd), .punch_val(p2_punch_val),
        .H_speed(p2_H_speed), .powerUp_cmd(p2_powerUp_cmd), .powerUp_val(p2_powerUp_val),
        .take_hit_pulse(p1_hit_p2), .incoming_damage_val(p1_outgoing_damage), .opponent_x(p1_x),
        .pos_x(p2_x), .pos_y(p2_y), .facing_right(p2_facing_right), .hp(p2_hp),
        .is_punching(p2_is_punching), .is_dead(p2_dead), .outgoing_damage_val(p2_outgoing_damage), .sprite_state(p2_sprite),
        .match_over(match_over), .i_won(p2_winner), .is_move_left(p2_is_move_left), .is_move_right(p2_is_move_right), .is_jumping(p2_is_jumping),
        .player(1'b1) // ADDED: Tells module this is Player 2
    );

    collision_unit collision(
        .p1_x(p1_x), .p1_y(p1_y), .p2_x(p2_x), .p2_y(p2_y),
        .p1_punching(p1_is_punching), .p2_punching(p2_is_punching),
        .p1_facing_right(p1_facing_right), .p2_facing_right(p2_facing_right),
        .p1_is_jumping(p1_is_jumping), // ADDED: Jump Punch Logic
        .p2_is_jumping(p2_is_jumping), // ADDED: Jump Punch Logic
        .p1_hit_p2(p1_hit_p2), .p2_hit_p1(p2_hit_p1)
    );

    // --- Clock Generation (50 MHz = 20ns period) ---
    always #10 CLOCK_50 = ~CLOCK_50;

	 // ========================================================================
// MOCK DISPLAY / PHYSICS ENGINE
// Simulates the module you haven't written yet!
// ========================================================================
reg signed [7:0] p1_mock_v_speed, p2_mock_v_speed;
localparam MOCK_GRAVITY = 10;
localparam MOCK_GROUND_Y = 10'd400;

always @(posedge CLOCK_50) begin
    if (~rst_n || start_new_round_wire) begin
        // Reset positions to match your START_X parameters
        p1_x <= 10'd30;
        p1_y <= MOCK_GROUND_Y;
        p1_mock_v_speed <= 0;

        p2_x <= 10'd120;
        p2_y <= MOCK_GROUND_Y;
        p2_mock_v_speed <= 0;
    end 
    else if (current_game_state == 3'd1) begin // Only move during PLAY state
        // --- P1 Mock Movement ---
        if (p1_is_move_right) p1_x <= p1_x + p1_H_speed;
        if (p1_is_move_left)  p1_x <= p1_x - p1_H_speed;

        // Mocking the jump arc
        if (p1_is_jumping && p1_y == MOCK_GROUND_Y) begin
            p1_mock_v_speed <= 30; // Initial jump velocity (upward)
            p1_y <= p1_y - 30;
        end else if (p1_y < MOCK_GROUND_Y) begin
            p1_mock_v_speed <= p1_mock_v_speed - MOCK_GRAVITY; // Gravity reduces upward speed
            
            // Apply speed to Y. (Subtracting a negative speed will ADD to Y, making them fall)
				p1_y <= $signed({1'b0, p1_y}) - p1_mock_v_speed;            
            if (p1_y > MOCK_GROUND_Y || p1_y < 0) p1_y <= MOCK_GROUND_Y; // Snap to floor
        end

        // --- P2 Mock Movement ---
        if (p2_is_move_right) p2_x <= p2_x + p2_H_speed;
        if (p2_is_move_left)  p2_x <= p2_x - p2_H_speed;

        if (p2_is_jumping && p2_y == MOCK_GROUND_Y) begin
            p2_mock_v_speed <= 30; 
            p2_y <= p2_y - 30;
        end else if (p2_y < MOCK_GROUND_Y) begin
            p2_mock_v_speed <= p2_mock_v_speed - MOCK_GRAVITY; 
				p2_y <= $signed({1'b0, p2_y}) - p2_mock_v_speed;            
            if (p2_y > MOCK_GROUND_Y) p2_y <= MOCK_GROUND_Y; 
        end
    end
end
	 
    // --- THE 4 TESTS ---
    initial begin
        // --- 0. INITIALIZATION ---
        CLOCK_50 = 0; rst_n = 1;
        p1_start_button = 0; p2_start_button = 0; rematch_button_wire = 0;
		  //p1_x = 0; p2_x = 0; p1_y = 400; p2_y = 400;
       
        p1_h_move = 0; p1_jump_cmd = 0; p1_punch_cmd = 0; p1_powerUp_cmd = 0;
        p2_h_move = 0; p2_jump_cmd = 0; p2_punch_cmd = 0; p2_powerUp_cmd = 0;
       
        p1_H_speed = 4'd10; p2_H_speed = 4'd10;   // Give them walking speed
        p1_punch_val = 4'd1; p2_punch_val = 4'd1; // Base damage multiplier

        // Reset the system
        #100 rst_n = 0; // Press reset
        #100 rst_n = 1; // Release reset

        // Start the game
        #100;
        p1_start_button = 1; p2_start_button = 1;
        #100; // Wait for state machine to enter PLAY

        // ==========================================
        // TEST 1: The Pushbox Test (X-Axis)
        // ==========================================
        $display("Starting Test 1: Pushbox...");
        p1_h_move = 2'b01; // Tell P1 to move RIGHT
       
        // Wait long enough for P1 (starting at x=30) to cross the screen and hit P2 (at x=120)
        #1000;
       
        p1_h_move = 2'b00; // Stop P1
        $display("Check Waveform: p1_x should have stopped before overlapping p2_x.");
        #500;

        // ==========================================
        // TEST 2: The Gravity Test (Y-Axis)
        // ==========================================
        $display("Starting Test 2: Gravity/Jumping...");
        p1_jump_cmd = 1; // Press Jump
        #40;             // Hold for 2 clock cycles
        p1_jump_cmd = 0; // Release Jump
       
        // Wait long enough for the jump arc to finish
        #3000;
        $display("Check Waveform: p1_y should go down (up visually) and return exactly to GROUND_Y.");

        // ==========================================
        // TEST 3: Invincibility Frames (Hit-Stun)
        // ==========================================
        $display("Starting Test 3: Hit-Stun & Invincibility...");
        // P1 punches P2 (They should be standing right next to each other from Test 1)
        p1_punch_cmd = 1;
        #100;
        p1_punch_cmd = 0;

        // Immediately try to make P2 punch back while stunned
        #20;
        p2_punch_cmd = 1;
        #100;
        p2_punch_cmd = 0;

        // Wait for stun to wear off
        #1000;
        $display("Check Waveform: p2_hp should drop once. p2_is_punching should NOT go high.");

        // ==========================================
        // TEST 4: Knockout & Game Over
        // ==========================================
        $display("Starting Test 4: Knockout...");
        p1_punch_val = 4'd15; // Set damage super high for instant KO!
       
        p1_punch_cmd = 1; // BOOM.
        #100;
        p1_punch_cmd = 0;

        #500;
        $display("Check Waveform: p2_hp should be 0. current_game_state should be GAMEOVER (2). p1_winner should be 1.");

        // End Simulation
        #1000;
        $stop;
    end
endmodule

