`timescale 1 ns/1 ns	//time scale for simulation

module Testbench();
    reg CLOCK_50;
    reg [0]  KEY;
    // --- SPI Controller Physical Pins (GPIO) ---
    reg        SPI_SCLK; // Clock from the microcontroller
    reg        SPI_CS;   // Chip select from the microcontroller
    reg        SPI_MOSI; // Data IN from the microcontroller
    reg        SPI_MISO;  // Data OUT to the microcontroller (if needed)

    wire [17:0] LEDR;
    wire [8:0]  LEDG;

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

    // Testing SPI Logic
    assign LEDR[1:0]    =   p1_h_move;
    assign LEDR[4]      =   p1_jump_cmd;
    assign LEDR[5]      =   p1_punch_cmd;
    assign LEDR[9:6]    =   p1_punch_val;
    assign LEDR[10]     =   p1_powerUp_cmd;
    assign LEDR[16:11]  =   p1_powerUp_val;
    assign LEDG[1:0]    =   p2_h_move;


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

    initial begin
        #20;
        KEY = 1'b1;
        CLOCK_50 = 1'b0;
        SPI_SCLK = 1'b0;
        SPI_MISO = 1'b0;
        SPI_MOSI = 1'b0;
        SPI_CS   = 1'b1;

        // SW = 18'b0;             // Ensure all bits are initialized
        // SW[17] = 1'b1;
        SW[10:0] = 11'b01111111111;         // 1023
        SW[17] = 1;
        KEY[3] = 0;
        #20;
        KEY[3] = 1;
        SW[17] = 0;
        KEY[2] = 0;
        SW[10:0] = 11'b10011001000;         // -200

        #20;
        SW[17] = 1;
        KEY = 4'b0111;

        #20;
        KEY = 4'b1110;

        #20;
        KEY[3] = 1;
        SW[17] = 0;
        KEY[3] = 0;
        SW[10:0] = 11'b00000001111;         // 15

        #20;
        SW[17] = 1;
        KEY = 4'b0111;

        #20
        SW[17] = 0;
        KEY = 4'b1011;
        SW[10:0] = 11'b00000000101;         // 5

        #20
        SW[17] = 1;
        KEY = 4'b0111;

        #20;
        KEY[3] = 1;
        SW[17] = 0;
        KEY[3] = 0;
        SW[10:0] = 11'b10000000001;         // -1

        #20
        SW[17] = 1;
        KEY = 4'b0111;

        #20;
        SW[17] = 1;
        KEY = 4'b1110;

        #20
        SW[17] = 0;
        KEY = 4'b0111;
        SW[10:0] = 11'b00000000111;         // 7

        #20
        SW[17] = 1;
        KEY = 4'b0111;

        #20
        SW[17] = 0;
        KEY = 4'b1101;
        SW[10:0] = 11'b10000001000;         // -8

        #20
        SW[17] = 1;
        KEY = 4'b0111;

    end

    always begin
        #10;
        CLOCK_50 <= ~CLOCK_50;  // Toggle the clock every 10 ns to create a 50 MHz clock
    end
endmodule