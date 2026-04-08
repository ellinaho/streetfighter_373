module game_engine(
    input wire clk,
    input wire rst,

    input  wire       p1_ready,
    input  wire       p2_ready,
    input  wire       restart_cmd,

    input  wire [6:0] p1_hp,
    input  wire [6:0] p2_hp,
    // To the rest of the System
    output reg [2:0]  game_state_out, // 00: STARTUP, 01: PLAY, 10: GAMEOVER
    output reg        round_reset,     // Pulses high to reset Player modules
    output wire [6:0] time_remaining,
    output wire match_over,
    output wire p1_winner,
    output wire p2_winner
);


     // State definitions and transitions
    localparam STARTUP = 3'd0, PLAY = 3'd1, GAMEOVER = 3'd2;
    reg [2:0] current_state, next_state;
    // typedef enum reg [1:0] {STARTUP = 2'b00, PLAY = 2'b01, GAMEOVER = 2'b10} state_t;
    // state_t current_state, next_state;

    reg [25:0] clk_counter;
    wire one_second_pulse = (clk_counter == 26'd49_999_999);

    always @(posedge clk) begin
        if (rst || current_state != PLAY) begin
            clk_counter <= 0;
        end
        else if (clk_counter == 26'd49_999_999) begin
            clk_counter <= 0;
        end
        else begin
            clk_counter <= clk_counter + 1;
        end
    end

    reg [6:0] round_timer; // 7 bits can hold up to 127
    assign time_remaining = round_timer;
    always @(posedge clk) begin
        if (rst || current_state == STARTUP) begin
            round_timer <= 7'd96; // Reset time to 99
        end else if (current_state == PLAY && one_second_pulse) begin
            if (round_timer > 0) begin
                round_timer <= round_timer - 1;
            end
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            current_state <= STARTUP;
        end else begin
            current_state <= next_state;
        end
    end

    // inputs
    always @(*) begin
        next_state = current_state;
        case (current_state)
            STARTUP: begin
                if (p1_ready && p2_ready) next_state = PLAY;
            end

            PLAY: begin
                if (p1_hp == 0 || p2_hp == 0 || round_timer == 0) next_state = GAMEOVER;
            end

            GAMEOVER: begin
                if (restart_cmd) next_state = STARTUP;
            end

            default: next_state = STARTUP;
        endcase
    end

    // outputs
    always @(*) begin
        game_state_out = current_state;
        round_reset = (current_state == STARTUP);
    end

	 assign match_over = (current_state == GAMEOVER);
    assign p1_winner = match_over && ((p2_hp == 0) || (p1_hp > p2_hp));
    assign p2_winner = match_over && ((p1_hp == 0) || (p2_hp > p1_hp));
	 
endmodule

