module SPI_slave (
    // --- System Clock ---
    input wire sys_clk,

    // --- Physical SPI Pins ---
    input wire SCLK,
    input wire MOSI,
    input wire SS,
    output wire MISO,

    // --- OUTGOING COMMANDS: Player 1 (To p1_controller) ---
    output reg [1:0]p1_H_move_cmd,
    output reg      p1_jump_cmd,
    output reg      p1_punch_cmd,
    output reg      p1_charge_cmd,

    // --- OUTGOING COMMANDS: Player 2 (To p2_controller) ---
    output reg [1:0]p2_H_move_cmd,
    output reg      p2_jump_cmd,
    output reg      p2_punch_cmd,
    output reg      p2_charge_cmd,

    // --- INCOMING TELEMETRY: Game State (From Engine/Referee) ---
    input wire      p1_win_in,
    input wire      p2_win_in,
    input wire      p1_hit_p2,         
    input wire      p2_hit_p1,        
    input wire      p1_jump,
    input wire      p2_jump,
    input wire      p1_punch,
    input wire      p2_punch,
    input wire      p1_charging,
    input wire      p2_charging
);

    reg [2:0] SCLK_sync;
    reg [2:0] SS_sync;
    reg [1:0] MOSI_sync;

    always @(posedge sys_clk) begin
        // Shifting the raw pin values into our registers
        SCLK_sync <= {SCLK_sync[1:0], SCLK};
        SS_sync   <= {SS_sync[1:0], SS};
        MOSI_sync <= {MOSI_sync[0], MOSI}; // MOSI doesn't need edge detection, just 2 DFFs to clean it
    end

    // Decoding the synchronizer history
    wire sclk_rise = (SCLK_sync[2:1] == 2'b01); 
    wire sclk_fall = (SCLK_sync[2:1] == 2'b10); 
    wire ss_active = ~SS_sync[1];               
    wire ss_start  = (SS_sync[2:1] == 2'b10);   
    wire mosi_data = MOSI_sync[1];

    // RECEIVER LAYER
    reg [2:0] bit_count;
    reg [7:0] shift_reg;
    reg       byte_ready;
    reg [7:0] byte_to_process;

    always @(posedge sys_clk) begin
        byte_ready <= 0;

        if (~ss_active) begin
            bit_count <= 0;
        end else if (sclk_rise) begin
            shift_reg <= {shift_reg[6:0], mosi_data}; // Shift MSB first
            bit_count <= bit_count + 1;
            
            if (bit_count == 3'd7) begin 
                byte_to_process <= {shift_reg[6:0], mosi_data};
                byte_ready <= 1; // Pulse ready!
            end
        end
    end

    reg byte_count;
    reg p1_active, p2_active;

    always @(posedge sys_clk) begin
        if (~ss_active) begin
            byte_count <= 0;
            p1_active  <= 0;
            p2_active  <= 0;
        end else if (byte_ready) begin
            case (byte_count)
                0:  begin   // Header
                    if (byte_to_process == 8'hA1) begin
                        p1_active <= 1; p2_active <= 0;
                    end else if (byte_to_process == 8'hA2) begin
                        p1_active <= 0; p2_active <= 1;
                    end
                    byte_count <= 1;
                end

                1:  begin   // Movement/Combat
                    if (p1_active)  begin
                        p1_H_move_cmd   <= byte_to_process[7:6];
                        p1_jump_cmd     <= byte_to_process[5];
                        p1_punch_cmd  <= byte_to_process[4];
                        p1_charge_cmd    <= byte_to_process[3];
                    end
                    else if (p2_active) begin
                        p2_H_move_cmd   <= byte_to_process[7:6];
                        p2_jump_cmd     <= byte_to_process[5];
                        p2_punch_cmd  <= byte_to_process[4];
                        p2_charge_cmd    <= byte_to_process[3];
                    end
                    byte_count <= 0;
                end

                // 2:  begin   // Power-up Multiplier
                //     if (p1_active) p1_PowerUp_val  <= byte_to_process[7:2];
                //     else if (p2_active) p2_PowerUp_val  <= byte_to_process[7:2];
                //     byte_count <= 3;
                // end

                // 3:  begin   // Status/Padding
                //     if (p1_active) p1_PowerUp_valid  <= byte_to_process[7];
                //     else if (p2_active) p2_PowerUp_valid  <= byte_to_process[7];
                //     byte_count <= 0;
                // end
            endcase
        end
    end

    // Transmission Layer
    reg [7:0] tx_buffer;
    always@(posedge sys_clk) begin
        if (ss_start) begin
            tx_buffer <= {
                // Byte 0: Hits and Wins
                p1_hit_p2, p2_hit_p1, p1_win_in, p2_win_in, p1_jump, p2_jump, p1_punch, p2_punch, 
                
                // Byte 1: Your new 2nd byte of data (Jumps and punches)
                p1_charging, p2_charging, 6'b000000,
            };
        end
        else if (ss_active && sclk_fall) begin
            tx_buffer <= {tx_buffer[14:0], 1'b0};
        end
    end

    assign MISO = (ss_active) ? tx_buffer[15] : 1'bz;
endmodule