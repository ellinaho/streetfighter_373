module hp_display (
    input  [7:0] hp,            // 8-bit HP (0 to 255)
    output [6:0] hex_hundreds,  // Connects to the left-most display
    output [6:0] hex_tens,      // Connects to the middle display
    output [6:0] hex_ones       // Connects to the right-most display
);

    // Quartus will easily synthesize this math for an 8-bit number
    wire [3:0] hundreds = hp / 100; 
    wire [3:0] tens     = (hp / 10) % 10; 
    wire [3:0] ones     = hp % 10; 
    
    // Instantiate decoders for all three digits
    bcd_to_7seg digit_hund (.bcd(hundreds), .seg(hex_hundreds));
    bcd_to_7seg digit_tens (.bcd(tens),     .seg(hex_tens));
    bcd_to_7seg digit_ones (.bcd(ones),     .seg(hex_ones));

endmodule

// Internal helper module to map 4-bit numbers to DE2-115 Active-Low segments
module bcd_to_7seg (
    input      [3:0] bcd,
    output reg [6:0] seg 
);
    always @(*) begin
        case (bcd)
            4'd0: seg = 7'b1000000;
            4'd1: seg = 7'b1111001;
            4'd2: seg = 7'b0100100;
            4'd3: seg = 7'b0110000;
            4'd4: seg = 7'b0011001;
            4'd5: seg = 7'b0010010;
            4'd6: seg = 7'b0000010;
            4'd7: seg = 7'b1111000;
            4'd8: seg = 7'b0000000;
            4'd9: seg = 7'b0010000;
            default: seg = 7'b1111111; // All OFF
        endcase
    end
endmodule