/* 
instructions:
1. use verilog code file as top module of quartus prime software
2. assignments -> pin planner 
    CLOCK_50: PIN_N2
    VGA_CLK: PIN_B8
    VGA_HS: PIN_A7
    VGA_VS: PIN_D8
    VGA_BLANK_N: PIN_D6
    VGA_SYNC_N: PIN_B7

    //FOR TESTING ONLY: need to assign 30 pins, this is fine for solid blocks of color
    VGA_R[9]: PIN_E10
    VGA_G[9]: PIN_D12
    VGA_B[9]: PIN_B12
3. start compilation play button
4. plug vga cable from onitor into blue vga port on de2
5. plug usb-blaster cable into PC and de2
6. turn on de2, ensure run/prog switch is on run
7. quartus: open tools -> programmer -> hardware setup -> USB blaster
8. add .sof file generated in output_files folder
9. click start

*/

module monitor_test(
    input CLOCK_50, //50MHz?
    output VGA_HS, //horizontal sync
    output VGA_VS, //vertical sync
    output VGA_BLANK_N, //blanking signal
    output VGA_SYNC_N,  //syncing sigal
    output VGA_CLK,  //25Mhz for monitor
    output [9:0] VGA_R, //VGA_R amount
    output [9:0] VGA_G, //VGA_G amount
    output [9:0] VGA_B //VGA_B amount
);

    //dividing de2 clock into monitor clock
    reg clock_25;
    always @(posedge CLOCK_50) begin
        clock_25 <= ~clock_25;
    end
    assign VGA_CLK = clock_25;

    //pixel coordinate incrementors (for drawing)
    reg [9:0] h_count = 0;
    reg [9:0] v_count = 0;

    always @(posedge clock_25) begin
        if (h_count == 799) begin
            h_count <= 0;
            if (v_count == 524) 
                v_count <= 0;
            else 
                v_count <= v_count + 1;
        end else begin
            h_count <= h_count + 1;
        end
    end

    //sync pulses for 640x480 at 60Hz ? not sure wut this is
    assign VGA_HS = (h_count >= 656 && h_count < 752) ? 1'b0 : 1'b1;
    assign VGA_VS = (v_count >= 490 && v_count < 492) ? 1'b0 : 1'b1;
    
    //blanking is 1 when in resolution area, 0 otherwise
    assign VGA_BLANK_N = (h_count < 640 && v_count < 480) ? 1'b1 : 1'b0;
    assign VGA_SYNC_N = 1'b1; // Tie high for standard VGA

    //test 1: drawing a VGA_R box
    /*
    //define box boundaries
    wire in_box = (h_count >= 100 && h_count <= 300 && v_count >= 100 && v_count <= 300);

    //if in box and in screen area output max VGA_R
    assign VGA_R = (in_box && VGA_BLANK_N) ? 10'h3FF : 10'h000;
    assign VGA_B = 10'h000; // Zero VGA_G
    assign VGA_G = 10'h000; // Zero VGA_B
    */

    //test 2: cycling thru colors

    /*
    //2 second timer (50 M cycles at 25MHz)
    reg [25:0] delay_count = 0;
    reg [1:0] color_state = 0; // Cycles through 0, 1, 2, 3

    always @(posedge clock_25) begin
        if (delay_count == 26'd50_000_000) begin
            delay_count <= 0;               // Reset the timer
            color_state <= color_state + 1; // Move to the next color
        end else begin
            delay_count <= delay_count + 1; // Keep counting
        end
    end

    //define box boundaries
    wire in_box = (h_count >= 100 && h_count <= 300 && v_count >= 100 && v_count <= 300);

    reg [9:0] red_val, green_val, blue_val;

    always @(*) begin
        //only output if in box area an in screen
        if (in_box && VGA_BLANK_N) begin
            case (color_state)
                2'd0: begin red_val = 10'h3FF; green_val = 10'h000; blue_val = 10'h000; end //red
                2'd1: begin red_val = 10'h000; green_val = 10'h3FF; blue_val = 10'h000; end //green
                2'd2: begin red_val = 10'h000; green_val = 10'h000; blue_val = 10'h3FF; end //blue
                2'd3: begin red_val = 10'h3FF; green_val = 10'h3FF; blue_val = 10'h000; end //yellow
            endcase
        end else begin
            // Draw a black background everywhere else
            red_val = 10'h000; green_val = 10'h000; blue_val = 10'h000;
        end
    end

    assign VGA_R = red_val;
    assign VGA_G = green_val;
    assign VGA_B = blue_val;


    */



endmodule

