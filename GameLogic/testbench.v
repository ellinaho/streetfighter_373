`timescale 1 ns/1 ns	//time scale for simulation

module Testbench();
    reg CLOCK_50;
    reg [0]  KEY
    // --- SPI Controller Physical Pins (GPIO) ---
    reg        SPI_SCLK, // Clock from the microcontroller
    reg        SPI_CS,   // Chip select from the microcontroller
    reg        SPI_MOSI, // Data IN from the microcontroller
    reg        SPI_MISO  // Data OUT to the microcontroller (if needed)

    wire p1_start_button;
    wire p2_start_button;

    wire rematch_button_wire; // Comes from SPI, goes to Engine

    wire [6:0] p1_hp;
    wire [6:0] p2_hp;

    wire [1:0] current_game_state;
    wire start_new_round_wire; // Comes from Engine, goes to Players

    localparam p1_start_x = 30;
    localparam p2_start_x = 600;

    // wire p1_jump_cmd, p1_punch_cmd, p1_kick_cmd, p1_powerUp_cmd, p1_take_hit, p1_facing_right;
    wire p1_jump_cmd, p1_punch_cmd, p1_powerUp_cmd, p1_take_hit, p1_facing_right;
    wire [1:0] p1_h_move;
    // wire [2:0] p1_punch_val, p1_kick_val, p1_powerUp_val;
    wire [3:0] p1_H_speed, p1_punch_val;
    wire [6:0] p1_incoming_damage_val, p1_outgoing_damage_val;
    wire [7:0] p1_powerUp_val;
    wire [9:0] p1_x, p1_y;

    // wire p1_is_punching, p1_is_kicking;
    wire p1_is_punching;

    // wire p2_jump_cmd, p2_punch_cmd, p2_kick_cmd, p2_powerUp_cmd, p2_take_hit, p2_facing_right;
    wire p2_jump_cmd, p2_punch_cmd, p2_powerUp_cmd, p2_take_hit, p2_facing_right;
    wire [1:0] p2_h_move;
    // wire [2:0] p2_punch_val, p2_kick_val, p2_powerUp_val;
    wire [3:0] p2_H_speed, p2_punch_val;
    wire [6:0] p2_incoming_damage_val, p2_outgoing_damage_val;
    wire [7:0] p2_powerUp_val;
    wire [9:0] p2_x, p2_y;

    // wire p2_is_punching, p2_is_kicking;
    wire p2_is_punching;

    assign p1_incoming_damage_val = p2_outgoing_damage_val;
    assign p2_incoming_damage_val = p1_outgoing_damage_val;

    // wire p1_hit_p2_upper, p1_hit_p2_lower, p2_hit_p1_upper, p2_hit_p1_lower;
    wire p1_hit_p2, p2_hit_p1;
    wire p1_dead, p2_dead;
    wire [2:0] p1_sprite, p2_sprite;

    SPI_slave spi_connect(
        .sys_clk(CLOCK_50), .SCLK(SPI_SCLK), .MOSI(SPI_MOSI), .SS(SPI_CS),
        .MISO(.SPI_MISO), .p1_H_move_cmd(p1_h_move), .p1_jump_cmd(p1_jump_cmd),
        .p1_punch_valid(p1_punch_cmd), .p1_punch_val(p1_punch_val),
        .p1_PowerUp_valid(p1_powerUp_cmd), .p1_PowerUp_val(p1_powerUp_val),
        .p2_H_move_cmd(p2_h_move), .p2_jump_cmd(p2_jump_cmd),
        .p2_punch_valid(p2_punch_cmd), .p2_punch_val(p2_punch_val),
        .p2_PowerUp_valid(p2_powerUp_cmd), .p2_PowerUp_val(p2_powerUp_val),
        .p1_win_in(1'b1), .p2_win_in(1'b0), .p1_hit_p2(1'b1), .p2_hit_p1(1'b0)
    );