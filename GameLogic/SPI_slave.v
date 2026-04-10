// module spi_slave (
//     // --- System Clock ---
//     input wire sys_clk,

//     // --- Physical SPI Pins ---
//     input wire SCLK,
//     input wire MOSI,
//     input wire SS,
//     output wire MISO,

//     // --- OUTGOING COMMANDS: Player 1 (To p1_controller) ---
//     output reg [1:0] p1_H_move_cmd,
//     output reg       p1_jump_cmd,
//     output reg       p1_punch_valid,
//     output reg [3:0] p1_punch_val,      // Increased to 4 bits for base damage
//     output reg       p1_PowerUp_valid,
//     output reg [5:0] p1_PowerUp_val,    // Expanded to 8 bits for integer float math (e.g. 24 = 2.4x)

//     // --- OUTGOING COMMANDS: Player 2 (To p2_controller) ---
//     output reg [1:0] p2_H_move_cmd,
//     output reg       p2_jump_cmd,
//     output reg       p2_punch_valid,
//     output reg [3:0] p2_punch_val,      // Increased to 4 bits
//     output reg       p2_PowerUp_valid,
//     output reg [5:0] p2_PowerUp_val,    // Expanded to 8 bits 

//     // --- INCOMING TELEMETRY: Game State (From Engine/Referee) ---
//     // input wire [6:0] p1_hp_in,
//     // input wire [6:0] p2_hp_in,
//     input wire       p1_win_in,
//     input wire       p2_win_in,
//     input wire       p1_hit_p2,         // Unified hit detection (Replaces upper/lower)
//     input wire       p2_hit_p1          // Unified hit detection (Replaces upper/lower)
// );

//     reg [2:0] SCLK_sync;
//     reg [2:0] SS_sync;
//     reg [1:0] MOSI_sync;

//     always @(posedge sys_clk) begin
//         // Shifting the raw pin values into our registers
//         SCLK_sync <= {SCLK_sync[1:0], SCLK};
//         SS_sync   <= {SS_sync[1:0], SS};
//         MOSI_sync <= {MOSI_sync[0], MOSI}; // MOSI doesn't need edge detection, just 2 DFFs to clean it
//     end

//     // Decoding the synchronizer history
//     wire sclk_rise = (SCLK_sync[2:1] == 2'b01); 
//     wire sclk_fall = (SCLK_sync[2:1] == 2'b10); 
//     wire ss_active = ~SS_sync[1];               
//     wire ss_start  = (SS_sync[2:1] == 2'b10);   
//     wire mosi_data = MOSI_sync[1];

//     // RECEIVER LAYER
//     reg [2:0] bit_count;
//     reg [7:0] shift_reg;
//     reg       byte_ready;
//     reg [7:0] byte_to_process;

//     always @(posedge sys_clk) begin
//         byte_ready <= 0;

//         if (~ss_active) begin
//             bit_count <= 0;
//         end else if (sclk_rise) begin
//             shift_reg <= {shift_reg[6:0], mosi_data}; // Shift MSB first
//             bit_count <= bit_count + 1;
            
//             if (bit_count == 3'd7) begin 
//                 byte_to_process <= {shift_reg[6:0], mosi_data};
//                 byte_ready <= 1; // Pulse ready!
//             end
//         end
//     end

//     reg [1:0] byte_count;
//     reg p1_active, p2_active;

//     always @(posedge sys_clk) begin
//         if (~ss_active) begin
//             byte_count <= 0;
//             p1_active  <= 0;
//             p2_active  <= 0;
//         end else if (byte_ready) begin
//             case (byte_count)
//                 0:  begin   // Header
//                     if (byte_to_process == 8'hA1) begin
//                         p1_active <= 1; p2_active <= 0;
//                     end else if (byte_to_process == 8'hA2) begin
//                         p1_active <= 0; p2_active <= 1;
//                     end
//                     byte_count <= 1;
//                 end

//                 1:  begin   // Movement/Combat
//                     if (p1_active)  begin
//                         p1_H_move_cmd   <= byte_to_process[7:6];
//                         p1_jump_cmd     <= byte_to_process[5];
//                         p1_punch_valid  <= byte_to_process[4];
//                         p1_punch_val    <= byte_to_process[3:0];
//                     end
//                     else if (p2_active) begin
//                         p2_H_move_cmd   <= byte_to_process[7:6];
//                         p2_jump_cmd     <= byte_to_process[5];
//                         p2_punch_valid  <= byte_to_process[4];
//                         p2_punch_val    <= byte_to_process[3:0];
//                     end
//                     byte_count <= 2;
//                 end

//                 2:  begin   // Power-up Multiplier
//                     if (p1_active) p1_PowerUp_val  <= byte_to_process[7:3];
//                     else if (p2_active) p2_PowerUp_val  <= byte_to_process[7:3];
//                     byte_count <= 3;
//                 end

//                 3:  begin   // Status/Padding
//                     if (p1_active) p1_PowerUp_valid  <= byte_to_process[7];
//                     else if (p2_active) p2_powerUp_valid  <= byte_to_process[7];
//                     byte_count <= 0;
//                 end
//             endcase
//         end
//     end

//     // Transmission Layer
//     reg [7:0] tx_buffer;
//     always@(posedge sys_clk) begin
//         if (ss_start) begin
//             tx_buffer <= {p1_hit_p2, p2_hit_p1, p1_win_in, p2_win_in, 4'b0000};
//         end
//         else if (ss_active && sclk_fall) begin
//             tx_buffer   <= {tx_buffer[6:0], 1'b0};
//         end
//     end

//     assign MISO = (ss_active) ? tx_buffer[7] : 1'bz;
// endmodule

// // module spi_slave (
// //     input wire SCLK,
// //     input wire MOSI,
// //     output wire MISO,
// //     input wire SS,
// //     output reg [7:0] received_data,
// //     input wire sys_clk,

// //     output reg [1:0] p1_H_move_cmd,
// //     output reg       p1_jump_cmd,
// //     output reg       p1_punch_valid,
// //     output reg [2:0] p1_punch_val,
// //     output reg       p1_kick_valid,
// //     output reg [2:0] p1_kick_val,
// //     output reg       p1_PowerUp_valid,
// //     output reg [2:0] p1_PowerUp_val,

// //     output reg [1:0] p2_H_move_cmd,
// //     output reg       p2_jump_cmd,
// //     output reg       p2_punch_valid,
// //     output reg [2:0] p2_punch_val,
// //     output reg       p2_kick_valid,
// //     output reg [2:0] p2_kick_val,
// //     output reg       p2_PowerUp_valid,  
// //     output reg [2:0] p2_PowerUp_val,

// //     input wire [6:0] p1_hp_in,
// //     input wire [6:0] p2_hp_in,
// //     input wire       p1_win_in,
// //     input wire       p2_win_in,

// //     input wire p1_hit_p2_upper, p1_hit_p2_lower, p2_hit_p1_upper, p2_hit_p1_lower
// // );

// // // SPI registers
//     // reg [2:0] bit_count = 0;
//     // reg [2:0] byte_count = 0;
//     // reg [7:0] temp_byte;
//     // reg byte_ready = 1;
//     // reg p1_active, p2_active = 0;
//     // reg [7:0] byte_to_process; // The stable "holding tank"

//     // Synchronization layer
//     // reg [1:0] byte_ready_sync;
//     // reg [1:0] ss_sync;
//     // always @(posedge sys_clk) begin
//     //     byte_ready_sync <= {byte_ready_sync[0], byte_ready};
//     //     ss_sync <= {ss_sync[0], SS};
//     // end
    
//     // wire br_edge = (byte_ready_sync == 2'b01); // Rising edge detection
//     // wire ss_active = !ss_sync[1];              // Active Low SS

//     // always @(posedge SCLK or posedge SS) begin
//     //     if (SS) begin
//     //         // Reset when FPGA is deselected
//     //         bit_count <= 0;
//     //         byte_ready <= 0;
//     //         // byte_count <= 0;
//     //     end else begin
//     //         // Shifting the byte each time as transmitted data
//     //         temp_byte <= {temp_byte[6:0], MOSI};
            
//     //         // Check if one package (8 bits) is transferred
//     //         if (bit_count == 7) begin
//     //             bit_count <= 0;
//     //             byte_ready <= 1;
//     //             byte_to_process <= {temp_byte[6:0], MOSI}; // Latch the full byte here!
//     //         end else begin
//     //             bit_count <= bit_count + 1;
//     //             byte_ready <= 0;
//     //         end
//     //     end
//     // end

//     // always @(posedge sys_clk) begin
//     //     if (!ss_active) begin
//     //         byte_count <= 0;
//     //     end else if (br_edge) begin
//     //         // Sending 4 data packages per player
//     //         case (byte_count)
//     //             0: begin
//     //                 if (byte_to_process == 8'hA1) begin
//     //                     p1_active <= 1;
//     //                     p2_active <= 0;
//     //                 end
//     //                 else if (byte_to_process == 8'hA2) begin
//     //                     p1_active <= 0;
//     //                     p2_active <= 1;
//     //                 end
//     //                 byte_count <= 1;
//     //             end
//     //             1: begin
//     //                 if (p1_active) begin
//     //                     p1_H_move_cmd <= byte_to_process[7:6];
//     //                     p1_jump_cmd   <= byte_to_process[5];
//     //                     p1_PowerUp_valid  <= byte_to_process[4];
//     //                     p1_PowerUp_val    <= byte_to_process[3:1];
//     //                 end
//     //                 else if (p2_active)    begin
//     //                     p2_H_move_cmd <= byte_to_process[7:6];
//     //                     p2_jump_cmd   <= byte_to_process[5];
//     //                     p2_PowerUp_valid  <= byte_to_process[4];
//     //                     p2_PowerUp_val    <= byte_to_process[3:1];
//     //                 end
//     //                 byte_count <= 2;
//     //             end
//     //             2: begin
//     //                 if (p1_active) begin
//     //                     p1_punch_valid <= byte_to_process[7];
//     //                     p1_kick_valid  <= byte_to_process[6];
//     //                     p1_punch_val   <= byte_to_process[5:3];
//     //                     p1_kick_val    <= byte_to_process[2:0];
//     //                 end
//     //                 else if (p2_active) begin
//     //                     p2_punch_valid <= byte_to_process[7];
//     //                     p2_kick_valid  <= byte_to_process[6];
//     //                     p2_punch_val   <= byte_to_process[5:3];
//     //                     p2_kick_val    <= byte_to_process[2:0];
//     //                 end
//     //                 byte_count <= 0;
//     //             end
//     //         endcase
//     //     end
//     // end

//     // // Example: Send a fixed value (0x55) on MISO
//     // // I gotta send back the data from FPGA to Main STM about hit data

//     // reg [7:0] tx_buffer; // data to be sent back to STM32
//     // always @(negedge SCLK or posedge SS) begin
//     //     if (SS) begin
//     //         // When not selected, MISO should usually be High-Z (disconnected)
//     //         // or preloaded with the first bit of the first byte.
//     //         tx_buffer <= {p1_UpperHit, p1_LowerHit, p2_UpperHit, p2_LowerHit, p1_win_in, p2_win_in, 2'b00};
//     //     end else begin
//     //         // Shift out the MSB (Bit 7) to the MISO pin
//     //         tx_buffer <= {tx_buffer[6:0], 1'b0};
//     //     end
//     // end

//     // // Always drive the MISO pin with the highest bit of our buffer
//     // assign MISO = (SS) ? 1'bz : tx_buffer[7];



// //     // sync SCK to the FPGA clock using a 3-bit shift register
// //     reg [2:0] SCKr;  always @(posedge clk) SCKr <= {SCKr[1:0], SCK};
// //     wire SCK_risingedge = (SCKr[2:1]==2'b01);  // now we can detect SCK rising edges
// //     wire SCK_fallingedge = (SCKr[2:1]==2'b10);  // and falling edges

// //     // same thing for SSEL
// //     reg [2:0] SSELr;  always @(posedge clk) SSELr <= {SSELr[1:0], SSEL};
// //     wire SSEL_active = ~SSELr[1];  // SSEL is active low
// //     wire SSEL_startmessage = (SSELr[2:1]==2'b10);  // message starts at falling edge
// //     wire SSEL_endmessage = (SSELr[2:1]==2'b01);  // message stops at rising edge

// //     // and for MOSI
// //     reg [1:0] MOSIr;  always @(posedge clk) MOSIr <= {MOSIr[0], MOSI};
// //     wire MOSI_data = MOSIr[1];

// //     // we handle SPI in 8-bit format, so we need a 3 bits counter to count the bits as they come in
// //     reg [2:0] bitcnt;

// //     reg byte_received;  // high when a byte has been received
// //     reg [7:0] byte_data_received;

// //     always @(posedge clk)
// //     begin
// //     if(~SSEL_active)
// //         bitcnt <= 3'b000;
// //     else
// //     if(SCK_risingedge)
// //         begin
// //             bitcnt <= bitcnt + 3'b001;

// //             // implement a shift-left register (since we receive the data MSB first)
// //             byte_data_received <= {byte_data_received[6:0], MOSI_data};
// //         end
// //     end

// //     always @(posedge clk) byte_received <= SSEL_active && SCK_risingedge && (bitcnt==3'b111);

// //     // we use the LSB of the data received to control an LED
// //     reg LED;
// //     always @(posedge clk) if(byte_received) LED <= byte_data_received[0];

// //     reg [7:0] byte_data_sent;

// //     reg [7:0] cnt;
// //     always @(posedge clk) if(SSEL_startmessage) cnt<=cnt+8'h1;  // count the messages

// //     always @(posedge clk)
// //     if(SSEL_active)
// //     begin
// //         if(SSEL_startmessage)
// //             byte_data_sent <= cnt;  // first byte sent in a message is the message count
// //         else
// //         if(SCK_fallingedge) begin
// //             if(bitcnt==3'b000)
// //                 byte_data_sent <= 8'h00;  // after that, we send 0s
// //             else
// //                 byte_data_sent <= {byte_data_sent[6:0], 1'b0};
// //         end
// //     end

// //     assign MISO = byte_data_sent[7];  // send MSB first
// //     // we assume that there is only one slave on the SPI bus
// //     // so we don't bother with a tri-state buffer for MISO
// //     // otherwise we would need to tri-state MISO when SSEL is inactive

// // endmodule

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
            tx_buffer <= {tx_buffer[15:0], 1'b0};
        end
    end

    assign MISO = (ss_active) ? tx_buffer[15] : 1'bz;
endmodule