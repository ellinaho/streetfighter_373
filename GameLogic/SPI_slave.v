module spi_slave (
    input wire SCLK,
    input wire MOSI,
    output wire MISO,
    input wire SS,
    output reg [7:0] received_data,
    input wire sys_clk
);

    // P1 registers
    reg [6:0]   p1_hp = 7'd100;
    reg [9:0]   p1_x = 10'd100; // Position on screen x-axis
    reg [9:0]   p1_y = 10'd100; // Position on screen y-axis
    reg [1:0]   p1_H_move;      // 00: idle, 01: right, 10: left
    reg	        p1_jump;	    // 0: idle, 1: jump
    reg	        p1_punch_valid;
    reg [2:0]   p1_punch_val;
    reg	        p1_kick_valid;
    reg [2:0]   p1_kick_val;
    reg [3:0]   p1_H_speed;
    reg [3:0]   p1_V_speed;
    reg 	    p1_PowerUp_valid;
    reg [2:0]   p1_PowerUp_val;
    reg         p1_UpperHit;
    reg         p1_LowerHit;
    reg         p1_win;

    // P2 registers
    reg [6:0]   p2_hp = 7'd100;
    reg [9:0]   p2_x = 10'd100; // Position on screen x-axis
    reg [9:0]   p2_y = 10'd100; // Position on screen y-axis
    reg [1:0]   p2_H_move;      // 00: idle, 01: right, 10: left
    reg	        p2_jump;	    // 0: idle, 1: jump
    reg	        p2_punch_valid;
    reg [2:0]   p2_punch_val;
    reg	        p2_kick_valid;
    reg [2:0]   p2_kick_val;
    reg [3:0]   p2_H_speed;
    reg [3:0]   p2_V_speed;
    reg 	    p2_PowerUp_valid;
    reg [2:0]   p2_PowerUp_val;
    reg         p2_UpperHit;
    reg         p2_LowerHit;
    reg         p2_win;

    // SPI registers
    reg [2:0] bit_count = 0;
    reg [2:0] byte_count = 0;
    reg [7:0] temp_byte;
    reg byte_ready = 1;
    reg p1_active, p2_active = 0;
    reg [7:0] byte_to_process; // The stable "holding tank"

    // Synchronization layer
    reg [1:0] byte_ready_sync;
    reg [1:0] ss_sync;
    always @(posedge sys_clk) begin
        byte_ready_sync <= {byte_ready_sync[0], byte_ready};
        ss_sync <= {ss_sync[0], SS};
    end
    
    wire br_edge = (byte_ready_sync == 2'b01); // Rising edge detection
    wire ss_active = !ss_sync[1];              // Active Low SS

    always @(posedge SCLK or posedge SS) begin
        if (SS) begin
            // Reset when FPGA is deselected
            bit_count <= 0;
            byte_ready <= 0;
            // byte_count <= 0;
        end else begin
            // Shifting the byte each time as transmitted data
            temp_byte <= {temp_byte[6:0], MOSI};
            
            // Check if one package (8 bits) is transferred
            if (bit_count == 7) begin
                bit_count <= 0;
                byte_ready <= 1;
                byte_to_process <= {temp_byte[6:0], MOSI}; // Latch the full byte here!
            end else begin
                bit_count <= bit_count + 1;
                byte_ready <= 0;
            end
        end
    end

    always @(posedge sys_clk) begin
        if (!ss_active) begin
            byte_count <= 0;
        end else if (br_edge) begin
            // Sending 4 data packages per player
            case (byte_count)
                0: begin
                    if (byte_to_process == 8'hA1) begin
                        p1_active <= 1;
                        p2_active <= 0;
                    end
                    else if (byte_to_process == 8'hA2) begin
                        p1_active <= 0;
                        p2_active <= 1;
                    end
                    byte_count <= 1;
                end
                1: begin
                    if (p1_active) begin
                        p1_H_move <= byte_to_process[7:6];
                        p1_jump   <= byte_to_process[5];
                        p1_PowerUp_valid  <= byte_to_process[4];
                        p1_PowerUp_val    <= byte_to_process[3:1];
                    end
                    else if (p2_active)    begin
                        p2_H_move <= byte_to_process[7:6];
                        p2_jump   <= byte_to_process[5];
                        p2_PowerUp_valid  <= byte_to_process[4];
                        p2_PowerUp_val    <= byte_to_process[3:1];
                    end
                    byte_count <= 2;
                end
                2: begin
                    if (p1_active) begin
                        p1_punch_valid <= byte_to_process[7];
                        p1_kick_valid  <= byte_to_process[6];
                        p1_punch_val   <= byte_to_process[5:3];
                        p1_kick_val    <= byte_to_process[2:0];
                    end
                    else if (p2_active) begin
                        p2_punch_valid <= byte_to_process[7];
                        p2_kick_valid  <= byte_to_process[6];
                        p2_punch_val   <= byte_to_process[5:3];
                        p2_kick_val    <= byte_to_process[2:0];
                    end
                    byte_count <= 0;
                end
            endcase
        end
    end

    // Example: Send a fixed value (0x55) on MISO
    // I gotta send back the data from FPGA to Main STM about hit data

    reg [7:0] tx_buffer; // data to be sent back to STM32
    always @(negedge SCLK or posedge SS) begin
        if (SS) begin
            // When not selected, MISO should usually be High-Z (disconnected)
            // or preloaded with the first bit of the first byte.
            tx_buffer <= {p1_UpperHit, p1_LowerHit, p2_UpperHit, p2_LowerHit, p1_win, p2_win, 2'b00};
        end else begin
            // Shift out the MSB (Bit 7) to the MISO pin
            tx_buffer <= {tx_buffer[6:0], 1'b0};
        end
    end

    // Always drive the MISO pin with the highest bit of our buffer
    assign MISO = (SS) ? 1'bz : tx_buffer[7];



    // // sync SCK to the FPGA clock using a 3-bit shift register
    // reg [2:0] SCKr;  always @(posedge clk) SCKr <= {SCKr[1:0], SCK};
    // wire SCK_risingedge = (SCKr[2:1]==2'b01);  // now we can detect SCK rising edges
    // wire SCK_fallingedge = (SCKr[2:1]==2'b10);  // and falling edges

    // // same thing for SSEL
    // reg [2:0] SSELr;  always @(posedge clk) SSELr <= {SSELr[1:0], SSEL};
    // wire SSEL_active = ~SSELr[1];  // SSEL is active low
    // wire SSEL_startmessage = (SSELr[2:1]==2'b10);  // message starts at falling edge
    // wire SSEL_endmessage = (SSELr[2:1]==2'b01);  // message stops at rising edge

    // // and for MOSI
    // reg [1:0] MOSIr;  always @(posedge clk) MOSIr <= {MOSIr[0], MOSI};
    // wire MOSI_data = MOSIr[1];

    // // we handle SPI in 8-bit format, so we need a 3 bits counter to count the bits as they come in
    // reg [2:0] bitcnt;

    // reg byte_received;  // high when a byte has been received
    // reg [7:0] byte_data_received;

    // always @(posedge clk)
    // begin
    // if(~SSEL_active)
    //     bitcnt <= 3'b000;
    // else
    // if(SCK_risingedge)
    //     begin
    //         bitcnt <= bitcnt + 3'b001;

    //         // implement a shift-left register (since we receive the data MSB first)
    //         byte_data_received <= {byte_data_received[6:0], MOSI_data};
    //     end
    // end

    // always @(posedge clk) byte_received <= SSEL_active && SCK_risingedge && (bitcnt==3'b111);

    // // we use the LSB of the data received to control an LED
    // reg LED;
    // always @(posedge clk) if(byte_received) LED <= byte_data_received[0];

    // reg [7:0] byte_data_sent;

    // reg [7:0] cnt;
    // always @(posedge clk) if(SSEL_startmessage) cnt<=cnt+8'h1;  // count the messages

    // always @(posedge clk)
    // if(SSEL_active)
    // begin
    //     if(SSEL_startmessage)
    //         byte_data_sent <= cnt;  // first byte sent in a message is the message count
    //     else
    //     if(SCK_fallingedge) begin
    //         if(bitcnt==3'b000)
    //             byte_data_sent <= 8'h00;  // after that, we send 0s
    //         else
    //             byte_data_sent <= {byte_data_sent[6:0], 1'b0};
    //     end
    // end

    // assign MISO = byte_data_sent[7];  // send MSB first
    // // we assume that there is only one slave on the SPI bus
    // // so we don't bother with a tri-state buffer for MISO
    // // otherwise we would need to tri-state MISO when SSEL is inactive

endmodule