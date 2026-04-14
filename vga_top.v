module vga_top(
    input CLOCK_50,

    input [3:0] p1_state,
    input p1_charging,
    input [4:0] p1_charge,
    input [5:0] p1_hp,
    input p1_dir, //1 is facing right?

    input [3:0] p2_state,
    input p2_charging,
    input [4:0] p2_charge,
    input  [5:0] p2_hp,
    input p2_dir, 

    input [1:0] game_state,
    input [6:0] time_left,

    output VGA_HS,
    output VGA_VS,
    output VGA_BLANK_N,
    output VGA_SYNC_N,
    output VGA_CLK,
    output [7:0] VGA_R,
    output [7:0] VGA_G,
    output [7:0] VGA_B,

    output reg [9:0] p1_x,
    output reg [9:0] p1_y, 
    output reg [9:0] p2_x,
    output reg [9:0] p2_y,

    output reg [3:0] p1_frame,
    output reg [3:0] p2_frame,

    output reg p1_half_done,
    output reg p2_half_done

);

//parameters 
    parameter GAME_W = 160, GAME_H = 120;
    parameter SPRITE_H = 53, SPRITE_W = 64;
    parameter FLOOR_Y = 115;
    parameter GROUND_LEVEL = FLOOR_Y - SPRITE_H;

    parameter RIGHT = 1, LEFT = 0;

    parameter IDLE = 0, WALK = 1, PUNCH = 2, JUMP = 3; 
    parameter JUMP_PUNCH = 4, GOT_HIT = 5, LOSE = 6, WIN = 7;

    parameter START = 0, GAME = 1, KO = 2;

//set initial coordinate values 
    initial begin
        p1_x = 10'd1009; //sprite top left coordinate
        p1_y = GROUND_LEVEL; 
        p2_x = 10'd110; //sprite top left coordinate
        p2_y = GROUND_LEVEL; 
        p1_frame = 0;
        p2_frame = 0;
        p1_half_done = 0;
        p2_half_done = 0;
    end

//animation speed and frame numbers 
    parameter IDLE_FRAMES = 4;
    parameter WALK_FRAMES = 5, WALK_SPEED = 1; 
    parameter PUNCH_FRAMES = 2;
    parameter P1_JUMP_FRAMES = 4, P2_JUMP_FRAMES = 6;
    parameter JUMP_SPEED_X = 1, JUMP_SPEED_Y = 2; 
    parameter P1_JUMP_PUNCH_FRAMES = 5, P2_JUMP_PUNCH_FRAMES = 8;
    parameter GOT_HIT_FRAMES = 2;
    parameter LOSE_FRAMES = 6, LOSE_SPEED = 2; 
    parameter WIN_FRAMES = 3;

//animation registers 
    reg [7:0] anim_timer1 = 8'd0, anim_timer2 = 8'd0;
	reg toggle = 0; //for jumping 1.5 lmao
    reg [3:0] prev_p1_state = 0, prev_p2_state = 0;
	reg [1:0] curr_state = 0, prev_state = 0;
	 
//animations, modifies frame + xy coordinates of player sprite
    always @(negedge VGA_VS) begin
		toggle <= ~toggle;
		prev_state <= curr_state;
		curr_state <= game_state;
		  
        prev_p1_state <= p1_state;
        prev_p2_state <= p2_state;
		
        //if reset 
        if ((curr_state == START) && (prev_state != START)) begin
            p1_frame <= 0;
            p2_frame <= 0;
            p1_x <= 10'd1009;
            p2_x <= 10'd110;
            p1_y <= GROUND_LEVEL;
            p2_y <= GROUND_LEVEL;
            
            anim_timer1 <= 0;
            anim_timer2 <= 0;
            p1_half_done <= 0;
            p2_half_done <= 0;
        end else begin
				
				if (p1_state != prev_p1_state) begin
					 if (prev_p1_state == JUMP && p1_state == JUMP_PUNCH) begin
						  // Let the jump carry over!
					 end else begin
						  p1_frame <= 0;
						  anim_timer1 <= 0;
						  p1_half_done <= 0;
					 end
				end

				if (p2_state != prev_p2_state) begin
					 if (prev_p2_state == JUMP && p2_state == JUMP_PUNCH) begin
						  // Let the jump carry over!
					 end else begin
						  p2_frame <= 0;
						  anim_timer2 <= 0;
						  p2_half_done <= 0;
					 end
				end
				
				if (p1_state == prev_p1_state || (prev_p1_state == JUMP && p1_state == JUMP_PUNCH)) begin
            case(p1_state)
                IDLE: begin
                    p1_y <= GROUND_LEVEL;
                    p1_half_done <= 0;

                    anim_timer1 <= anim_timer1 + 1;

                    if (anim_timer1 >= (60/IDLE_FRAMES - 1)) begin
                        anim_timer1 <= 0;
                        if (p1_frame >= (IDLE_FRAMES - 1)) 
                            p1_frame <= 0;
                        else 
                            p1_frame <= p1_frame + 1'b1;
                    end
                end   
                WALK: begin
                    //update coordinates 
                    p1_y <= GROUND_LEVEL;
                    p1_half_done <= 0;
                    if (p1_dir == RIGHT) begin
                        if ((p1_x + 10'd64 - 10'd15) < 10'd160) begin p1_x <= p1_x + WALK_SPEED; end 
                    end else begin 
                        if ((p1_x + 10'd15) > 0 && (p1_x + 10'd15) < 10'd512) begin p1_x <= p1_x - WALK_SPEED; end 
                    end

                    anim_timer1 <= anim_timer1 + 1;

                    if (anim_timer1 >= (40 /WALK_FRAMES - 1)) begin 
                        anim_timer1 <= 0;
                        if (p1_frame >= (WALK_FRAMES - 1)) begin
                            p1_frame <= 0;
                        end else 
                            p1_frame <= p1_frame + 1;
                    end
                end
                PUNCH: begin
                    anim_timer1 <= anim_timer1 + 1;
                    if (anim_timer1 >= (24/(2*PUNCH_FRAMES)-1)) begin
                        anim_timer1 <= 0;
                        if (~p1_half_done) begin //if throw not done
                            if (p1_frame >= (PUNCH_FRAMES - 1)) begin
                                p1_half_done <= 1;
                                p1_frame <= PUNCH_FRAMES -1;
                            end else begin
                                p1_frame <= p1_frame + 1;
                            end
                        end else begin
                            if (p1_frame <= 0) begin
                                p1_half_done <= 1;
                                p1_frame <= 0;
                            end else begin
                                p1_frame <= p1_frame - 1;
                            end
                        end
                    end
                end
                JUMP: begin
                    //x coordinate: 
                    if (!(p1_half_done && p1_frame == 0)) begin
                        if (p1_dir == RIGHT) begin
                            if ((p1_x + 10'd64 - 10'd15) < 10'd160) begin p1_x <= p1_x + JUMP_SPEED_X; end 
                        end else begin 
                            if ((p1_x + 10'd15) > 0 && (p1_x + 10'd15) < 10'd512) begin p1_x <= p1_x - JUMP_SPEED_X; end 
                        end
                    end
                    
                    if (~p1_half_done) begin
                        if (p1_y > 10'd2) p1_y <= p1_y - (toggle ? 10'd2 : 10'd1);
                        else p1_y <= 10'd0;
                    end else begin 
                        // FALL PURELY BASED ON THE FLOOR, IGNORE ANIMATION FRAMES!
                        if (p1_y < GROUND_LEVEL) p1_y <= p1_y + (toggle ? 10'd2 : 10'd1);
                        else p1_y <= GROUND_LEVEL;
                    end
                    
                    //animation
                    anim_timer1 <= anim_timer1 + 1;
                    if (anim_timer1 >= ((p1_frame == (P1_JUMP_FRAMES -1)) ? 13:5)) begin
                        anim_timer1 <= 0;
                        if (~p1_half_done) begin //if up not done
                            if (p1_frame >= (P1_JUMP_FRAMES - 1)) begin
                                p1_half_done <= 1;
                                p1_frame <= P1_JUMP_FRAMES -1;
                            end else begin
                                p1_frame <= p1_frame + 1;
                            end
                        end else begin
                            if (p1_frame <= 0) begin
                                p1_half_done <= 1;
                                p1_frame <= 0;
                            end else begin
                                p1_frame <= p1_frame - 1;
                            end
                        end
                    end
                end
                JUMP_PUNCH: begin //Fixed
                    //x coordinate: 
                    if (!(p1_half_done && p1_frame == 0)) begin
                        if (p1_dir == RIGHT) begin
                            if ((p1_x + 10'd64 - 10'd15) < 10'd160) begin p1_x <= p1_x + JUMP_SPEED_X; end 
                        end else begin 
                            if ((p1_x + 10'd15) > 0 && (p1_x + 10'd15) < 10'd512) begin p1_x <= p1_x - JUMP_SPEED_X; end 
                        end
                    end
                    
                    if (~p1_half_done) begin
                        if (p1_y > 10'd2) p1_y <= p1_y - (toggle ? 10'd2 : 10'd1);
                        else p1_y <= 10'd0;
                    end else begin 
                        // FALL PURELY BASED ON THE FLOOR, IGNORE ANIMATION FRAMES!
                        if (p1_y < GROUND_LEVEL) p1_y <= p1_y + (toggle ? 10'd2 : 10'd1);
                        else p1_y <= GROUND_LEVEL;
                    end

                    //animation
                    anim_timer1 <= anim_timer1 + 1;
                    if (anim_timer1 >= ((p1_frame == (P1_JUMP_PUNCH_FRAMES - 1)) ? 11 : 4)) begin
                        anim_timer1 <= 0;
                        if (~p1_half_done) begin //if up not done
                            if (p1_frame >= (P1_JUMP_PUNCH_FRAMES - 1)) begin
                                p1_half_done <= 1;
                                p1_frame <= P1_JUMP_PUNCH_FRAMES -1;
                            end else begin
                                p1_frame <= p1_frame + 1;
                            end
                        end else begin
                            if (p1_frame <= 0) begin
                                p1_half_done <= 1;
                                p1_frame <= 0;
                            end else begin
                                p1_frame <= p1_frame - 1;
                            end
                        end
                    end
                end
                GOT_HIT: begin
                    p1_y <= GROUND_LEVEL;
                    anim_timer1 <= anim_timer1 + 1;
                    if (anim_timer1 >= (20/(2*GOT_HIT_FRAMES)-1)) begin
                        anim_timer1 <= 0;
                        if (~p1_half_done) begin //if throw not done
                            if (p1_frame >= (GOT_HIT_FRAMES - 1)) begin
                                p1_half_done <= 1;
                                p1_frame <= GOT_HIT_FRAMES -1;
                            end else begin
                                p1_frame <= p1_frame + 1;
                            end
                        end else begin
                            if (p1_frame <= 0) begin
                                p1_half_done <= 0;
                                p1_frame <= 0;
                            end else begin
                                p1_frame <= p1_frame - 1;
                            end
                        end
                    end
                end
                LOSE: begin //Fixed
                    //update coordinates 
                    p1_y <= GROUND_LEVEL;
                    if (p1_dir == RIGHT && p1_frame != LOSE_FRAMES - 1) begin
                        if ((p1_x + 10'd15) > 0 && (p1_x + 10'd15) < 10'd512) begin p1_x <= p1_x - LOSE_SPEED; end 
                    end else if (p1_dir == LEFT && p1_frame != LOSE_FRAMES - 1) begin 
                        if ((p1_x + 10'd64 - 10'd15) < 10'd160) begin p1_x <= p1_x + LOSE_SPEED; end 
                    end

                    anim_timer1 <= anim_timer1 + 1;

                    if (anim_timer1 >= 11) begin 
                        anim_timer1 <= 0;
                        if (p1_frame >= (LOSE_FRAMES - 1)) begin
                            p1_frame <= LOSE_FRAMES - 1;
                        end else 
                            p1_frame <= p1_frame + 1;
                    end
                end
                WIN: begin //Fixed 
                    p1_y <= GROUND_LEVEL;
                    anim_timer1 <= anim_timer1 + 1;
                    if (anim_timer1 >= 29) begin
                        anim_timer1 <= 0;
                        if (p1_frame >= (WIN_FRAMES - 1)) 
                            p1_frame <= 0;
                        else 
                            p1_frame <= p1_frame + 1'b1;
                    end
                end
            endcase
				end
				
				if (p2_state == prev_p2_state || (prev_p2_state == JUMP && p2_state == JUMP_PUNCH)) begin

            case(p2_state)
                IDLE: begin
                    p2_y <= GROUND_LEVEL;
                    p2_half_done <= 0;
                    anim_timer2 <= anim_timer2 + 1;
                    if (anim_timer2 >= (60/IDLE_FRAMES - 1)) begin
                        anim_timer2 <= 0;
                        if (p2_frame >= (IDLE_FRAMES - 1)) 
                            p2_frame <= 0;
                        else 
                            p2_frame <= p2_frame + 1'b1;
                    end
                end   
                WALK: begin
                    //update coordinates 
                    p2_y <= GROUND_LEVEL;
                    p2_half_done <= 0;
                    if (p2_dir == RIGHT) begin
                        if ((p2_x + 10'd64 - 10'd15) < 10'd160) begin p2_x <= p2_x + WALK_SPEED; end 
                    end else begin 
                        if ((p2_x + 10'd15) > 0 && (p2_x + 10'd15) < 10'd512) begin p2_x <= p2_x - WALK_SPEED; end 
                    end

                    anim_timer2 <= anim_timer2 + 1;

                    if (anim_timer2 >= (40 /WALK_FRAMES - 1)) begin 
                        anim_timer2 <= 0;
                        if (p2_frame >= (WALK_FRAMES - 1)) begin
                            p2_frame <= 0;
                        end else 
                            p2_frame <= p2_frame + 1;
                    end
                end
                PUNCH: begin
                    anim_timer2 <= anim_timer2 + 1;
                    if (anim_timer2 >= (24/(2*PUNCH_FRAMES)-1)) begin
                        anim_timer2 <= 0;
                        if (~p2_half_done) begin //if throw not done
                            if (p2_frame >= (PUNCH_FRAMES - 1)) begin
                                p2_half_done <= 1;
                                p2_frame <= PUNCH_FRAMES -1;
                            end else begin
                                p2_frame <= p2_frame + 1;
                            end
                        end else begin
                            if (p2_frame <= 0) begin
                                p2_half_done <= 1;
                                p2_frame <= 0;
                            end else begin
                                p2_frame <= p2_frame - 1;
                            end
                        end
                    end
                end
                JUMP: begin //Fixed
                    //x coordinate: 
                    if (!(p2_half_done && p2_frame == (P2_JUMP_FRAMES -1))) begin
                        if (p2_dir == RIGHT) begin
                            if ((p2_x + 10'd64 - 10'd15) < 10'd160) begin p2_x <= p2_x + JUMP_SPEED_X; end 
                        end else begin 
                            if ((p2_x + 10'd15) > 0 && (p2_x + 10'd15) < 10'd512) begin p2_x <= p2_x - JUMP_SPEED_X; end 
                        end
                    end
                    
                    if (~p2_half_done) begin
                        if (p2_y > 10'd2) p2_y <= p2_y - (toggle ? 10'd2 : 10'd1);
                        else p2_y <= 10'd0;
                    end else begin 
                        // FALL PURELY BASED ON THE FLOOR, IGNORE ANIMATION FRAMES!
                        if (p2_y < GROUND_LEVEL) p2_y <= p2_y + (toggle ? 10'd2 : 10'd1);
                        else p2_y <= GROUND_LEVEL;
                    end
                    //animation
                    anim_timer2 <= anim_timer2 + 1;
                    if (anim_timer2 >= ((p2_frame == 2 || p2_frame == 3) ? 15 : 7)) begin
                        anim_timer2 <= 0;
                        
                        if (p2_frame == 2) begin
                            p2_half_done <= 1;
                        end

                        if (p2_frame >= (P2_JUMP_FRAMES - 1)) begin
                            p2_frame <= P2_JUMP_FRAMES - 1;
                        end else p2_frame <= p2_frame + 1;
                    end
                end
                JUMP_PUNCH: begin //Fixed
                    //x coordinate: 
                    if (!(p2_half_done && p2_frame == (P2_JUMP_PUNCH_FRAMES -1))) begin
                        if (p2_dir == RIGHT) begin
                            if ((p2_x + 10'd64 - 10'd15) < 10'd160) begin p2_x <= p2_x + JUMP_SPEED_X; end 
                        end else begin 
                            if ((p2_x + 10'd15) > 0 && (p2_x + 10'd15) < 10'd512) begin p2_x <= p2_x - JUMP_SPEED_X; end 
                        end
                    end
                    
                    if (~p2_half_done) begin
                        if (p2_y > 10'd2) p2_y <= p2_y - (toggle ? 10'd2 : 10'd1);
                        else p2_y <= 10'd0;
                    end else begin 
                        // FALL PURELY BASED ON THE FLOOR, IGNORE ANIMATION FRAMES!
                        if (p2_y < GROUND_LEVEL) p2_y <= p2_y + (toggle ? 10'd2 : 10'd1);
                        else p2_y <= GROUND_LEVEL;
                    end
                    //animation
                    anim_timer2 <= anim_timer2 + 1;

                    if (p2_frame == 4 && anim_timer2 == 3) begin
                        p2_half_done <= 1; 
                    end

                    if (anim_timer2 >= ((p2_frame == 4) ? 14 : 6)) begin
                        anim_timer2 <= 0;
                        if (p2_frame >= (P2_JUMP_PUNCH_FRAMES - 1)) begin
                            p2_frame <= P2_JUMP_PUNCH_FRAMES - 1;
                        end else p2_frame <= p2_frame + 1;
                    end
                end
                GOT_HIT: begin
                    p2_y <= GROUND_LEVEL;
                    anim_timer2 <= anim_timer2 + 1;
                    if (anim_timer2 >= (20/(2*GOT_HIT_FRAMES)-1)) begin
                        anim_timer2 <= 0;
                        if (~p2_half_done) begin //if throw not done
                            if (p2_frame >= (GOT_HIT_FRAMES - 1)) begin
                                p2_half_done <= 1;
                                p2_frame <= GOT_HIT_FRAMES -1;
                            end else begin
                                p2_frame <= p2_frame + 1;
                            end
                        end else begin
                            if (p2_frame <= 0) begin
                                p2_half_done <= 0;
                                p2_frame <= 0;
                            end else begin
                                p2_frame <= p2_frame - 1;
                            end
                        end
                    end
                end
                LOSE: begin //Fixed
                    //update coordinates 
                    p2_y <= GROUND_LEVEL;
                    if (p2_dir == RIGHT && p2_frame != LOSE_FRAMES - 1) begin
                        if ((p2_x + 10'd15) > 0 && (p2_x + 10'd15) < 10'd512) begin p2_x <= p2_x - LOSE_SPEED; end 
                    end else if (p2_dir == LEFT && p2_frame != LOSE_FRAMES - 1) begin 
                        if ((p2_x + 10'd64 - 10'd15) < 10'd160) begin p2_x <= p2_x + LOSE_SPEED; end 
                    end

                    anim_timer2 <= anim_timer2 + 1;

                    if (anim_timer2 >= 11) begin 
                        anim_timer2 <= 0;
                        if (p2_frame >= (LOSE_FRAMES - 1)) begin
                            p2_frame <= LOSE_FRAMES - 1;
                        end else 
                            p2_frame <= p2_frame + 1;
                    end
                end
                WIN: begin //Fixed
                    p2_y <= GROUND_LEVEL;
                    anim_timer2 <= anim_timer2 + 1;
                    if (anim_timer2 >= 29) begin
                        anim_timer2 <= 0;
                        if (p2_frame >= (WIN_FRAMES - 1)) 
                            p2_frame <= 0;
                        else 
                            p2_frame <= p2_frame + 1'b1;
                    end
                end
            endcase
				end
		end
			
	 end

//ROM WIRES declaration
    wire [16:0] p1_rom_addr, p2_rom_addr;
    wire [14:0] bg_rom_addr, elem_rom_addr;
    wire [7:0] bg_rom_data, p1_rom_data, p2_rom_data, elem_rom_data;

    //HARDWARE ROM declaration
    p1_rom player1_memory (.address(p1_rom_addr), .clock(CLOCK_50), .q(p1_rom_data));
    p2_rom player2_memory (.address(p2_rom_addr), .clock(CLOCK_50), .q(p2_rom_data));
    bg_rom background_memory (.address(bg_rom_addr), .clock(CLOCK_50), .q(bg_rom_data));
    elem_rom element_memory (.address(elem_rom_addr), .clock(CLOCK_50), .q(elem_rom_data));

    pixel my_pixel (
        .CLOCK_50   (CLOCK_50),
        .bg_rom_addr(bg_rom_addr),
        .bg_rom_data(bg_rom_data),
        .p1_rom_addr(p1_rom_addr),
        .p1_rom_data(p1_rom_data),
        .p2_rom_addr(p2_rom_addr),
        .p2_rom_data(p2_rom_data),
        .elem_rom_addr(elem_rom_addr),
        .elem_rom_data(elem_rom_data),

        .p1_x       (p1_x),
        .p1_y       (p1_y),
        .p1_state   (p1_state),
        .p1_frame   (p1_frame),
        .p1_hp      (p1_hp),
        .p1_charge  (p1_charge),
        .p1_charging(p1_charging),
        .p1_dir     (p1_dir),

        .p2_x       (p2_x),
        .p2_y       (p2_y),
        .p2_state   (p2_state),
        .p2_frame   (p2_frame),
        .p2_hp      (p2_hp),
        .p2_charge  (p2_charge),
        .p2_charging(p2_charging),
        .p2_dir     (p2_dir),
		  
		.time_left  (time_left),
		  
		.game_state (game_state),
        
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