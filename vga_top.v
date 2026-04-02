module vga_top(
    input CLOCK_50,

    output VGA_HS,
    output VGA_VS,
    output VGA_BLANK_N,
    output VGA_SYNC_N,
    output VGA_CLK,
    output [7:0] VGA_R,
    output [7:0] VGA_G,
    output [7:0] VGA_B
);

    //coordinates
    parameter GAME_W = 160;
    parameter SPRITE_H = 53;
    parameter SPRITE_W = 64;
    parameter FLOOR_Y = 110;
    parameter GROUND_LEVEL = FLOOR_Y - SPRITE_H;
    
    //player states
    parameter IDLE = 0;
    parameter WALK = 1;
    parameter PUNCH = 2;
    parameter JUMP = 3;

    //animations
    parameter P1_IDLE_FRAMES = 4;
    parameter P1_WALK_FRAMES = 5;
    parameter P1_WALK_SPEED = 1; //change whenever
    parameter P1_PUNCH_FRAMES = 3;
    parameter P1_JUMP_FRAMES = 4;
    parameter P1_JUMP_SPEED_X = 1;
    parameter P1_JUMP_SPEED_Y = 2; 

    //player registers
    reg [9:0] p1_x = 10'd10; //sprite top left coordinate
    reg [9:0] p1_y = GROUND_LEVEL; 
    reg [3:0] p1_state = JUMP; 
    reg [3:0] p1_frame = 0;

    //timing
    reg [3:0] anim_timer1 = 4'd0;
	reg throw_done = 0;
    reg up_done = 0;

    reg [7:0] test_timer = 7'd0;
    reg test_timer_on = 0;


always @(negedge VGA_VS) begin
    case(p1_state)
        IDLE: begin
            anim_timer1 <= anim_timer1 + 1;
            if (anim_timer1 >= (60/P1_IDLE_FRAMES - 1)) begin
                anim_timer1 <= 0;
                if (p1_frame >= (P1_IDLE_FRAMES - 1)) 
                    p1_frame <= 0;
                else 
                    p1_frame <= p1_frame + 1'b1;
            end
        end   
        WALK: begin
            //update coordinates 
            p1_x <= p1_x + P1_WALK_SPEED;
            //bound check CHANGE TODO

            anim_timer1 <= anim_timer1 + 1;

            if (anim_timer1 >= (40 /P1_WALK_FRAMES - 1)) begin 
                anim_timer1 <= 0;
                if (p1_frame >= (P1_WALK_FRAMES - 1)) begin
                    p1_frame <= 0;
                end else 
                    p1_frame <= p1_frame + 1;
            end
        end
        PUNCH: begin
            anim_timer1 <= anim_timer1 + 1;
            if (anim_timer1 >= (24/(2*P1_PUNCH_FRAMES)-1)) begin
                anim_timer1 <= 0;
                if (~throw_done) begin //if throw not done
                    if (p1_frame >= (P1_PUNCH_FRAMES - 1)) begin
                        throw_done = 1;
                        p1_frame <= P1_PUNCH_FRAMES -1;
                    end else begin
                        p1_frame <= p1_frame + 1;
                    end
                end else begin
                    if (p1_frame <= 0) begin
                        throw_done = 0;
                        p1_frame <= 0;
                        //p1_state <= IDLE;
                    end else begin
                        p1_frame <= p1_frame - 1;
                    end
                end
            end
        end
        JUMP: begin
            //x coordinate: 
            if (p1_x < (GAME_W - SPRITE_W)) begin
					p1_x <= p1_x + P1_JUMP_SPEED_X;
				end
            
				if (~up_done) begin
					p1_y <= p1_y - P1_JUMP_SPEED_Y;
				end else begin
					p1_y <= p1_y + P1_JUMP_SPEED_Y;
				end
            //animation
            anim_timer1 <= anim_timer1 + 1;
            if (anim_timer1 >= ((p1_frame == (P1_JUMP_FRAMES -1)) ? 13:5)) begin
                anim_timer1 <= 0;
                if (~up_done) begin //if up not done
                    if (p1_frame >= (P1_JUMP_FRAMES - 1)) begin
                        up_done = 1;
                        p1_frame <= P1_JUMP_FRAMES -1;
                    end else begin
                        p1_frame <= p1_frame + 1;
                    end
                end else begin
                    if (p1_frame <= 0) begin
                        up_done = 0;
                        p1_frame <= 0;
                        p1_y <= GROUND_LEVEL;
                        p1_x <= 10;
                        //p1_state <= IDLE;
                    end else begin
                        p1_frame <= p1_frame - 1;
                    end
                end
            end
			end


    endcase
end
//ROM WIRES
    wire [16:0] p1_rom_addr; //change
    wire [14:0] bg_rom_addr;
    wire [7:0] bg_rom_data, p1_rom_data;


//HARDWARE ROM
    p1_rom player1_memory (.address(p1_rom_addr), .clock(CLOCK_50), .q(p1_rom_data));
    bg_rom background_memory (.address(bg_rom_addr), .clock(CLOCK_50), .q(bg_rom_data));

//call graphics, TODO: ensure inputs are all right
    pixel my_pixel (
        .CLOCK_50   (CLOCK_50),
        .bg_rom_addr(bg_rom_addr),
        .bg_rom_data(bg_rom_data),
        .p1_rom_addr(p1_rom_addr),
        .p1_rom_data(p1_rom_data),
        .p1_x       (p1_x),
        .p1_y       (p1_y),
        .p1_state   (p1_state),
        .p1_frame   (p1_frame),
        
        .VGA_HS     (VGA_HS),
        .VGA_VS     (VGA_VS),
        .VGA_BLANK_N(VGA_BLANK_N),
        .VGA_SYNC_N (VGA_SYNC_N),
        .VGA_CLK    (VGA_CLK),
        .VGA_R      (VGA_R),
        .VGA_G      (VGA_G),
        .VGA_B      (VGA_B)
    );

endmodule
