module fpga_top(
    input CLOCK_50,

    //for testing
    input  wire [4:0]  KEY,
    input  wire [17:0] SW,
    input  wire [17:0] LEDR,

    output VGA_HS,
    output VGA_VS,
    output VGA_BLANK_N,
    output VGA_SYNC_N,
    output VGA_CLK,
    output [7:0] VGA_R,
    output [7:0] VGA_G,
    output [7:0] VGA_B,

    //SPI
    input  wire        SPI_SCLK, // Clock from the microcontroller
    input  wire        SPI_CS,   // Chip select from the microcontroller
    input  wire        SPI_MOSI, // Data IN from the microcontroller
    output wire        SPI_MISO  // Data OUT to the microcontroller (if needed)
    
);

    //driven by player controller?
    wire [3:0] p1_state;
    wire p1_charging;
    wire [4:0] p1_charge;
    wire [5:0] p1_hp;
    wire p1_dir; //1 is facing right?

    wire [3:0] p2_state;
    wire p2_charging;
    wire [4:0] p2_charge;
    wire  [5:0] p2_hp;
    wire p2_dir;  

    //driven by game_engine
    wire [1:0] game_state;
    wire [6:0] time_left;

    //driven by vga 
    wire [9:0] p1_x, p1_y;
    wire [9:0] p2_x, p2_y;

    //spi placeholddersfsdf
    wire       p1_jump_cmd, p2_jump_cmd;
    wire       p1_punch_cmd, p2_punch_cmd;
    wire       p1_charge_cmd, p2_charge_cmd;
    wire [1:0] p1_move_cmd, p2_move_cmd;   // Now it can hold both bits!

    wire       p1_start_button, p2_start_button;
    wire       rst_button;

    // assign p1_punch_cmd    =   ~KEY[1];
    // assign p1_jump_cmd    =   ~KEY[3];
    // assign p1_charge_cmd = SW[13];
    // assign p1_move_cmd	=   SW[17:16];

    // assign p2_punch_cmd = 1'b0;
    // assign p2_jump_cmd = 1'b0;
    // assign p2_charge_cmd = SW[12];

    // assign p1_start_button = SW[15];
    // assign p2_start_button = SW[14];
	// assign rst_button = ~KEY[0];

    assign LEDR[1:0] = p1_move_cmd;
    assign LEDR[2] = p1_jump_cmd;
    assign LEDR[3] = p1_punch_cmd;
    assign LEDR[4] = p1_charge_cmd;
    
    assign LEDR[7:6] = p2_move_cmd;
    assign LEDR[8] = p2_jump_cmd;
    assign LEDR[9] = p2_punch_cmd;
    assign LEDR[10] = p2_charge_cmd;

/*
vga_top top1(
    .CLOCK_50(CLOCK_50),
    .p1_state(p1_state),
    .p1_charging(p1_charging),
    .p1_charge(p1_charge),
    .p1_hp(p1_hp),
    .p1_dir(p1_dir),

    .p2_state(p2_state),
    .p2_charging(p2_charging),
    .p2_charge(p2_charge),
    .p2_hp(p2_hp),
    .p2_dir(p2_dir),

    .game_state(game_state),
    .time_left(time_left),

    .VGA_HS      (VGA_HS),
    .VGA_VS      (VGA_VS),
    .VGA_BLANK_N (VGA_BLANK_N),
    .VGA_SYNC_N  (VGA_SYNC_N),
    .VGA_CLK     (VGA_CLK),
    .VGA_R       (VGA_R),
    .VGA_G       (VGA_G),
    .VGA_B       (VGA_B),

    .p1_x(p1_x),
    .p1_y(p1_y),
    .p2_x(p2_x),
    .p2_y(p2_y)
);

game_top top2(
    .CLOCK_50(CLOCK_50),

    .p1_x(p1_x),
    .p1_y(p1_y),
    .p2_x(p2_x),
    .p2_y(p2_y),

    //spi inputs
    .p1_jump_cmd(p1_jump_cmd),
    .p1_punch_cmd(p1_punch_cmd),
    .p1_charge_cmd(p1_charge_cmd),
    .p1_move_cmd(p1_move_cmd),

    .p2_jump_cmd(p2_jump_cmd),
    .p2_punch_cmd(p2_punch_cmd),  
    .p2_charge_cmd(p2_charge_cmd),
    .p2_move_cmd(p2_move_cmd),

    .p1_state(p1_state),
    .p1_charging(p1_charging),
    .p1_charge(p1_charge),
    .p1_hp(p1_hp),
    .p1_dir(p1_dir),

    .p2_state(p2_state),
    .p2_charging(p2_charging),
    .p2_charge(p2_charge),
    .p2_hp(p2_hp),
    .p2_dir(p2_dir),

    .game_state(game_state),
    .time_left(time_left),

    //testing? maybe keep
    .p1_start_button(p1_start_button),
    .p2_start_button(p2_start_button),
	 .rst_button(rst_button)

);
*/

SPI_slave s1(
		.sys_clk(CLOCK_50),
		.SCLK(SPI_SCLK),
		.MOSI(SPI_MOSI),
		.SS(SPI_CS),
		.MISO(SPI_MISO),
		.p1_H_move_cmd(p1_move_cmd),
		.p1_jump_cmd(p1_jump_cmd),
		.p1_punch_cmd(p1_punch_cmd),
		.p1_charge_cmd(p1_charge_cmd),
		.p2_H_move_cmd(p2_move_cmd),
		.p2_jump_cmd(p2_jump_cmd),
		.p2_punch_cmd(p2_punch_cmd),
		.p2_charge_cmd(p2_charge_cmd),
		.p1_win_in(1'd0),
		.p2_win_in(1'd0),
		.p1_hit_p2(1'd0),
		.p2_hit_p1(1'd1),
		.p1_jump(1'd1),
		.p2_jump(1'd1),
		.p1_punch(1'd0),
		.p2_punch(1'd0),
		.p1_charging(1'd1),
		.p2_charging(1'd0)
	);

endmodule

