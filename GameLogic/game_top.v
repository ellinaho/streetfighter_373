module game_top(
    // --- System Essentials ---
    input  wire        CLOCK_50,
    input  wire [4:0]  KEY,      // KEY[0] will be our physical reset button

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
    output wire        SPI_MISO,  // Data OUT to the microcontroller (if needed)

    //Testing with LEDs
    output wire [17:0] LEDR,
    output wire [8:0]  LEDG,

    input  wire [17:0] SW
);

    wire p1_start_button;
    wire p2_start_button;

    wire rematch_button_wire; // Comes from SPI, goes to Engine

    wire [6:0] p1_hp;
    wire [6:0] p2_hp;

    wire [1:0] current_game_state;
    wire start_new_round_wire; // Comes from Engine, goes to Players

    localparam p1_start_x = 300;
    localparam p2_start_x = 320;

    // wire p1_jump_cmd, p1_punch_cmd, p1_kick_cmd, p1_powerUp_cmd, p1_take_hit, p1_facing_right;
    wire p1_jump_cmd, p1_punch_cmd, p1_powerUp_cmd, p1_take_hit, p1_facing_right;
    wire [1:0] p1_h_move;
    // wire [2:0] p1_punch_val, p1_kick_val, p1_powerUp_val;
    wire [3:0] p1_H_speed, p1_punch_val;
    wire [6:0] p1_incoming_damage_val, p1_outgoing_damage_val;
    wire [5:0] p1_powerUp_val;
    wire [9:0] p1_x, p1_y;

    // wire p1_is_punching, p1_is_kicking;
    wire p1_is_punching;

    // wire p2_jump_cmd, p2_punch_cmd, p2_kick_cmd, p2_powerUp_cmd, p2_take_hit, p2_facing_right;
    wire p2_jump_cmd, p2_punch_cmd, p2_powerUp_cmd, p2_take_hit, p2_facing_right;
    wire [1:0] p2_h_move;
    // wire [2:0] p2_punch_val, p2_kick_val, p2_powerUp_val;
    wire [3:0] p2_H_speed, p2_punch_val;
    wire [6:0] p2_incoming_damage_val, p2_outgoing_damage_val;
    wire [5:0] p2_powerUp_val;
    wire [9:0] p2_x, p2_y;

    // wire p2_is_punching, p2_is_kicking;
    wire p2_is_punching;

    assign p1_incoming_damage_val = p2_outgoing_damage_val;
    assign p2_incoming_damage_val = p1_outgoing_damage_val;

    // wire p1_hit_p2_upper, p1_hit_p2_lower, p2_hit_p1_upper, p2_hit_p1_lower;
    wire p1_hit_p2, p2_hit_p1;
    wire p1_dead, p2_dead;
    wire [2:0] p1_sprite, p2_sprite;
    // assign p1_take_hit = p2_hit_p1_lower | p2_hit_p1_upper;
    // assign p2_take_hit = p1_hit_p2_lower | p1_hit_p2_upper;

    // Testing SPI Logic
    // assign LEDR[1:0]    =   p1_h_move;
    // assign LEDR[4]      =   p1_jump_cmd;
    // assign LEDR[5]      =   p1_punch_cmd;
    // assign LEDR[9:6]    =   p1_punch_val;
    // assign LEDR[10]     =   p1_powerUp_cmd;
    // assign LEDR[16:11]  =   p1_powerUp_val;
    // assign LEDG[1:0]    =   p2_h_move;

    assign p1_punch_cmd    =   KEY[1];
    assign p1_jump_cmd    =   KEY[3];

    assign p1_punch_val =   SW[3:0];
    assign p2_punch_val =   SW[7:4];
    
    assign p1_powerUp_cmd = KEY[2];
    assign p1_PowerUp_val = SW[13:8];

    game_engine game(.clk(CLOCK_50), .rst(KEY), .p1_ready(p1_start_button), .p2_ready(p2_start_button), .restart_cmd(rematch_button_wire),
    .p1_hp(p1_hp), .p2_hp(p2_hp), .game_state_out(current_game_state), .round_reset(start_new_round_wire));
    player_controller #(.START_X(p1_start_x), .START_FACING(1)) p1(
        .clk(CLOCK_50), .reset(start_new_round_wire), .h_move_cmd(p1_h_move),
        .jump_cmd(p1_jump_cmd), .punch_cmd(p1_punch_cmd), .punch_val(p1_punch_val),
        // .kick_cmd(p1_kick_cmd), .kick_val(p1_kick_val), .H_speed(p1_H_speed),
        .H_speed(p1_H_speed),
        .powerUp_cmd(p1_powerUp_cmd), .powerUp_val(p1_powerUp_val), .take_hit_pulse(p2_hit_p1),
        .incoming_damage_val(p1_incoming_damage_val), .pos_x(p1_x), .pos_y(p1_y),
        .facing_right(p1_facing_right), .hp(p1_hp), .is_punching(p1_is_punching),
        // .is_kicking(p1_is_kicking), .outgoing_damage_val(p1_outgoing_damage_val)
        .is_dead(p1_dead), .outgoing_damage_val(p1_outgoing_damage_val), .sprite_state(p1_sprite)
    );
    player_controller #(.START_X(p2_start_x), .START_FACING(0)) p2(
        .clk(CLOCK_50), .reset(start_new_round_wire), .h_move_cmd(p2_h_move),
        .jump_cmd(p2_jump_cmd), .punch_cmd(p2_punch_cmd), .punch_val(p2_punch_val),
        // .kick_cmd(p2_kick_cmd), .kick_val(p2_kick_val), .H_speed(p2_H_speed),
        .H_speed(p2_H_speed),
        .powerUp_cmd(p2_powerUp_cmd), .powerUp_val(p2_powerUp_val), .take_hit_pulse(p1_hit_p2),
        .incoming_damage_val(p2_incoming_damage_val), .pos_x(p2_x), .pos_y(p2_y),
        .facing_right(p2_facing_right), .hp(p2_hp), .is_punching(p2_is_punching),
        // .is_kicking(p2_is_kicking), .outgoing_damage_val(p2_outgoing_damage_val)
        .is_dead(p2_dead), .outgoing_damage_val(p2_outgoing_damage_val), .sprite_state(p2_sprite)
    );
    collision_unit collision(
        .p1_x(p1_x), .p1_y(p1_y), .p2_x(p2_x), .p2_y(p2_y),
        .p1_punching(p1_is_punching), .p2_punching(p2_is_punching),
        // .p1_kicking(p1_is_kicking), .p2_kicking(p2_is_kicking),
        .p1_facing_right(p1_facing_right), .p2_facing_right(p2_facing_right),
        // .p1_hit_p2_upper(p1_hit_p2_upper), .p1_hit_p2_lower(p1_hit_p2_lower),
        // .p2_hit_p1_upper(p2_hit_p1_upper), .p2_hit_p1_lower(p2_hit_p1_lower)
        .p1_hit_p2(p1_hit_p2), .p2_hit_p1(p2_hit_p1)
    );
    // SPI_slave spi_connect(
    //     .sys_clk(CLOCK_50), .SCLK(SPI_SCLK), .MOSI(SPI_MOSI), .SS(SPI_CS),
    //     .MISO(.SPI_MISO), .p1_H_move_cmd(p1_h_move), .p1_jump_cmd(p1_jump_cmd),
    //     .p1_punch_valid(p1_punch_cmd), .p1_punch_val(p1_punch_val),
    //     .p1_PowerUp_valid(p1_powerUp_cmd), .p1_PowerUp_val(p1_powerUp_val),
    //     .p2_H_move_cmd(p2_h_move), .p2_jump_cmd(p2_jump_cmd),
    //     .p2_punch_valid(p2_punch_cmd), .p2_punch_val(p2_punch_val),
    //     .p2_PowerUp_valid(p2_powerUp_cmd), .p2_PowerUp_val(p2_powerUp_val),
    //     .p1_win_in(p2_dead), .p2_win_in(p1_dead), .p1_hit_p2(p1_hit_p2), .p2_hit_p1(p2_hit_p1)
    // );
endmodule