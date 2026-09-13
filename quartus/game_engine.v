module game_engine(
    input clk,

    //fpga board
    input wire start_button,      // Button 1: Resets/forces state to START
    input wire game_button,  // Button 2: Forces state to GAME

    //from player, ready to start game
    input  wire       p1_ready,
    input  wire       p2_ready,
    input  wire [6:0] p1_hp,
    input  wire [6:0] p2_hp,
    //input  wire       restart_cmd,

    //output to game top
    output reg [1:0]  game_state, // 00: START, 01: GAME, 10: KO
    output reg [6:0] time_left,
    output wire [1:0] winner
);

    localparam START = 3'd0, GAME = 3'd1, KO = 3'd2;

    initial begin
        game_state = START;
        time_left = 16;
    end

//6 second timer for game time
    reg [28:0] game_counter = 29'd0;  // Counter for the 50 MHz clock
    reg [2:0] curr_state = START;
    reg [2:0] next_state;

    // Constant for 6 seconds (50,000,000 cycles * 6 seconds - 1)
    localparam [28:0] SIX_SEC_COUNT = 29'd299_999_999; 

    always @(posedge clk or posedge start_button) begin
        if (start_button) begin
            time_left <= 7'd16;       // Reset value
            game_counter <= 29'd0;     // Reset your 50MHz counter too
        end else if (curr_state == START || game_button) begin
            time_left <= 7'd16;       // Keep it glued to 16
            game_counter <= 29'd0;     // Keep the internal clock counter at 0
        end
        else if (curr_state == GAME) begin
            if (game_counter == SIX_SEC_COUNT) begin
                game_counter <= 29'd0;
                if (time_left > 0) begin time_left <= time_left - 1'b1; end
            end else begin
                game_counter <= game_counter + 1'b1;
            end
        end
    end

//10 second timer for KO screen
    localparam [28:0] TEN_SEC_COUNT = 29'd499_999_999; 
    reg [28:0] ko_counter;
    reg ko_done;

    always @(posedge clk or posedge start_button) begin
        if (start_button) begin
            ko_counter <= 29'd0;
            ko_done  <= 1'b0;
        end 
        else if (curr_state != KO) begin
            ko_counter <= 29'd0;
            ko_done  <= 1'b0;
        end 
        else begin
            if (ko_counter == TEN_SEC_COUNT) begin
                ko_done <= 1'b1; 
            end else begin
                ko_counter <= ko_counter + 1'b1;
                ko_done  <= 1'b0;
            end
        end
end
//state machine

    always @(posedge clk or posedge start_button) begin
        if (start_button) begin
            curr_state <= START; 
        end else if (game_button) begin
            curr_state <= GAME;         // Button 2: Force to GAME
        end else begin
            curr_state <= next_state;
        end
    end

    // inputs
    always @(*) begin
        next_state = curr_state;
        case (curr_state)
            START: begin
                if (p1_ready && p2_ready) next_state = GAME;
            end

            GAME: begin
                if (p1_hp == 0 || p2_hp == 0 || time_left == 0) next_state = KO;
            end

            KO: begin
                if (ko_done) next_state = START;
            end

            default: next_state = START;
        endcase
    end

    // outputs
    always @(*) begin
        game_state = curr_state;
    end

    assign winner = (curr_state != KO) ? 2'd2 :                  // If not KO, 2
            (p2_hp == 0 && p1_hp > 0) ? 2'd0 :           // If P2 dead, P1 wins
            (p1_hp == 0 && p2_hp > 0) ? 2'd1 : 2'd2;     // If P1 dead, P2 wins, else draw
endmodule