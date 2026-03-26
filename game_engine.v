module game_engine(
    input wire clk,
    input wire rst,

    input  wire       p1_ready,
    input  wire       p2_ready,
    input  wire       restart_cmd,

    input  wire [6:0] p1_hp,
    input  wire [6:0] p2_hp,
    // To the rest of the System
    output reg [1:0]  game_state_out, // 00: STARTUP, 01: PLAY, 10: GAMEOVER
    output reg        round_reset     // Pulses high to reset Player modules
);

     // State definitions and transitions
    typedef enum reg [1:0] {STARTUP = 2'b00, PLAY = 2'b01, GAMEOVER = 2'b10} state_t;
    state_t current_state, next_state;

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
                if (p1_hp == 0 || p2_hp == 0) next_state = GAMEOVER;
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

endmodule