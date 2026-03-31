module game_top(
    // --- System Essentials ---
    input  wire        CLOCK_50,
    input  wire [0:0]  KEY,      // KEY[0] will be our physical reset button

    // --- VGA Display Physical Pins ---
    output wire [7:0]  VGA_R,    // 8-bit Red video signal
    output wire [7:0]  VGA_G,    // 8-bit Green video signal
    output wire [7:0]  VGA_B,    // 8-bit Blue video signal
    output wire        VGA_HS,   // Horizontal sync pulse
    output wire        VGA_VS,   // Vertical sync pulse
    output wire        VGA_CLK,  // Video clock (often 25MHz for 640x480)
    output wire        VGA_BLANK_N, 
    output wire        VGA_SYNC_N,

    // --- SPI Controller Physical Pins (GPIO) ---
    input  wire        SPI_SCLK, // Clock from the microcontroller
    input  wire        SPI_CS,   // Chip select from the microcontroller
    input  wire        SPI_MOSI, // Data IN from the microcontroller
    output wire        SPI_MISO  // Data OUT to the microcontroller (if needed)
);

    wire p1_start_button;
    wire p2_start_button;

    wire rematch_button_wire; // Comes from SPI, goes to Engine

    wire [6:0] p1_hp;
    wire [6:0] p2_hp;

    wire [1:0] current_game_state;
    wire start_new_round_wire; // Comes from Engine, goes to Players

    localparam p1_start_x = 30;
    localparam p2_start_x = 600;

    wire p1_jump_cmd, p1_punch_cmd, p1_kick_cmd, p1_powerUp_cmd, p1_take_hit, p1_facing_right;
    wire [1:0] p1_h_move;
    wire [2:0] p1_punch_val, p1_kick_val, p1_powerUp_val;
    wire [3:0] p1_H_speed;
    wire [4:0] p1_incoming_damage_val, p1_outgoing_damage_val;
    wire [9:0] p1_x, p1_y;

    wire p1_is_punching, p1_is_kicking;

    wire p2_jump_cmd, p2_punch_cmd, p2_kick_cmd, p2_powerUp_cmd, p2_take_hit, p2_facing_right;
    wire [1:0] p2_h_move;
    wire [2:0] p2_punch_val, p2_kick_val, p2_powerUp_val;
    wire [3:0] p2_H_speed;
    wire [4:0] p2_incoming_damage_val, p2_outgoing_damage_val;
    wire [9:0] p2_x, p2_y;

    wire p2_is_punching, p2_is_kicking;

    assign p1_incoming_damage_val = p2_outgoing_damage_val;
    assign p2_incoming_damage_val = p1_outgoing_damage_val;

    wire p1_hit_p2_upper, p1_hit_p2_lower, p2_hit_p1_upper, p2_hit_p1_lower;

    assign p1_take_hit = p2_hit_p1_lower | p2_hit_p1_upper;
    assign p2_take_hit = p1_hit_p2_lower | p1_hit_p2_upper;

    game_engine game(.clk(CLOCK_50), .rst(KEY), .p1_ready(p1_start_button), .p2_ready(p2_start_button), restart_cmd(rematch_button_wire),
    .p1_hp(p1_hp), .p2_hp(p2_hp), .game_state_out(current_game_state), .round_reset(engine_reset_pulse));
    player_controller #(.START_X(p1_start_x), .START_FACING(1)) p1(
        .clk(CLOCK_50), .reset(start_new_round_wire), .h_move_cmd(p1_h_move),
        .jump_cmd(p1_jump_cmd), .punch_cmd(p1_punch_cmd), .punch_val(p1_punch_val),
        .kick_cmd(p1_kick_cmd), .kick_val(p1_kick_val), .H_speed(p1_H_speed),
        .powerUp_cmd(p1_powerUp_cmd), .powerUp_val(p1_powerUp_val), .take_hit_pulse(p1_take_hit),
        .incoming_damage_val(p1_incoming_damage_val), .pos_x(p1_x), .pos_y(p1_y),
        .facing_right(p1_facing_right), .hp(p1_hp), .is_punching(p1_is_punching),
        .is_kicking(p1_is_kicking), .outgoing_damage_val(p1_outgoing_damage_val)
    );
    player_controller #(.START_X(p2_start_x), .START_FACING(0)) p2(
        .clk(CLOCK_50), .reset(start_new_round_wire), .h_move_cmd(p2_h_move),
        .jump_cmd(p2_jump_cmd), .punch_cmd(p2_punch_cmd), .punch_val(p2_punch_val),
        .kick_cmd(p2_kick_cmd), .kick_val(p2_kick_val), .H_speed(p2_H_speed),
        .powerUp_cmd(p2_powerUp_cmd), .powerUp_val(p2_powerUp_val), .take_hit_pulse(p2_take_hit),
        .incoming_damage_val(p2_incoming_damage_val), .pos_x(p2_x), .pos_y(p2_y),
        .facing_right(p2_facing_right), .hp(p2_hp), .is_punching(p2_is_punching),
        .is_kicking(p2_is_kicking), .outgoing_damage_val(p2_outgoing_damage_val)
    );
    collision_unit collision(
        .p1_x(p1_x), .p1_y(p1_y), .p2_x(p2_x), .p2_y(p2_y),
        .p1_punching(p1_is_punching), .p2_punching(p2_is_punching),
        .p1_kicking(p1_is_kicking), .p2_kicking(p2_is_kicking),
        .p1_facing_right(p1_facing_right), .p2_facing_right(p2_facing_right),
        .p1_hit_p2_upper(p1_hit_p2_upper), .p1_hit_p2_lower(p1_hit_p2_lower),
        .p2_hit_p1_upper(p2_hit_p1_upper), .p2_hit_p1_lower(p2_hit_p1_lower)
    );
    SPI_slave spi_connect(
        .SCLK(SPI_SCLK), .MOSI(SPI_MOSI), .MISO(.SPI_MISO),
        .SS(SPI_CS), .received_data(), .sys_clk(CLOCK_50)
    );
endmodule