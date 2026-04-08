module fpga_top(
    input CLOCK_50,

    //for testing
    input  wire [4:0]  KEY,
    input  wire [17:0] SW,

    output VGA_HS,
    output VGA_VS,
    output VGA_BLANK_N,
    output VGA_SYNC_N,
    output VGA_CLK,
    output [7:0] VGA_R,
    output [7:0] VGA_G,
    output [7:0] VGA_B

    //SPI
    input  wire        SPI_SCLK, // Clock from the microcontroller
    input  wire        SPI_CS,   // Chip select from the microcontroller
    input  wire        SPI_MOSI, // Data IN from the microcontroller
    output wire        SPI_MISO,  // Data OUT to the microcontroller (if needed)
    
);

//testing
    wire p1_start_button;
    wire p2_start_button;

    assign p1_start_button = 1'b1;
    assign p2_start_button = 1'b1;
    assign rematch_button_wire = 1'b0;

//game logic random stuff
    wire rematch_button_wire; // Comes from SPI, goes to Engine
    wire start_new_round_wire; // Comes from Engine, goes to Players

//controller
    wire p1_jump_cmd, p1_punch_cmd, p1_take_hit, p1_dead, p1_hit_p2;
    wire [1:0] p1_h_move;
    wire [3:0] p1_punch_val;
    wire [6:0] p1_incoming_damage_val, p1_outgoing_damage_val;

    wire p2_jump_cmd, p2_punch_cmd, p2_take_hit, p2_dead, p2_hit_p1;
    wire [1:0] p2_h_move;
    wire [3:0] p2_punch_val;
    wire [6:0] p2_incoming_damage_val, p2_outgoing_damage_val;

    wire match_over, p1_winner, p2_winner;
    wire p1_is_move_left, p1_is_move_right, p1_is_jumping;
    wire p2_is_move_left, p2_is_move_right, p2_is_jumping;


//Sprite and background dimensions & coordinates
    parameter GAME_W = 160, GAME_H = 120;
    parameter SPRITE_H = 53, SPRITE_W = 64;
    parameter FLOOR_Y = 115;
    parameter GROUND_LEVEL = FLOOR_Y - SPRITE_H;

//wires used commonly by both vga and game logic
    wire [3:0] p1_state;
    wire p1_charging;
    wire [4:0] p1_charge;
    wire [5:0] p1_hp;
    wire p1_dir; //1 is facing right?

    wire [3:0] p2_state;
    wire p2_charging;
    wire [4:0] p2_charge;
    wire  [5:0] p2_hp;
    wire p2_dir;  

    reg [1:0] game_state = 0;
    wire [6:0] time_left;

// registers 
    reg [9:0] p1_x = 10'd1009; //sprite top left coordinate
    reg [9:0] p1_y = GROUND_LEVEL; 
    reg [3:0] p1_frame = 0;

    reg [9:0] p2_x = 10'd110; //sprite top left coordinate
    reg [9:0] p2_y = GROUND_LEVEL; 
    reg [3:0] p2_frame = 0;


//strictly animations
    //Animations, dealing with frames
    parameter IDLE_FRAMES = 4;
    parameter WALK_FRAMES = 5, WALK_SPEED = 1; 
    parameter PUNCH_FRAMES = 2;
    parameter P1_JUMP_FRAMES = 4, P2_JUMP_FRAMES = 6;
    parameter JUMP_SPEED_X = 1, JUMP_SPEED_Y = 2; 
    parameter P1_JUMP_PUNCH_FRAMES = 5, P2_JUMP_PUNCH_FRAMES = 8;
    parameter GOT_HIT_FRAMES = 2;
    parameter LOSE_FRAMES = 6, LOSE_SPEED = 2; 
    parameter WIN_FRAMES = 3;
    reg [5:0] anim_timer1 = 5'd0, anim_timer2 = 5'd0;
	reg p1_half_done = 0, p2_half_done = 0; 
    parameter RIGHT = 1, LEFT = 0;

    parameter IDLE = 0, WALK = 1, PUNCH = 2, JUMP = 3; 
    parameter JUMP_PUNCH = 4, GOT_HIT = 5, LOSE = 6, WIN = 7;

    //animations, modifies frame + xy coordinates of player sprite
    always @(negedge VGA_VS) begin
        case(p1_state)
            IDLE: begin
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
                if (p1_dir == RIGHT) begin p1_x <= p1_x + WALK_SPEED; end
                else begin p1_x <= p1_x - WALK_SPEED; end

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
                            p1_half_done = 1;
                            p1_frame <= PUNCH_FRAMES -1;
                        end else begin
                            p1_frame <= p1_frame + 1;
                        end
                    end else begin
                        if (p1_frame <= 0) begin
                            p1_half_done = 0;
                            p1_frame <= 0;
                        end else begin
                            p1_frame <= p1_frame - 1;
                        end
                    end
                end
            end
            JUMP: begin
                //x coordinate: 
                if (p1_dir == RIGHT) begin
                    if (p1_x < (GAME_W - SPRITE_W)) begin p1_x <= p1_x + JUMP_SPEED_X; end //change logic
                end else begin 
                    if (p1_x > 0) begin p1_x <= p1_x - JUMP_SPEED_X; end //change logic
                end 
                
                if (~p1_half_done) begin
                    p1_y <= p1_y - JUMP_SPEED_Y;
                end else begin
                    p1_y <= p1_y + JUMP_SPEED_Y;
                end
                //animation
                anim_timer1 <= anim_timer1 + 1;
                if (anim_timer1 >= ((p1_frame == (P1_JUMP_FRAMES -1)) ? 13:5)) begin
                    anim_timer1 <= 0;
                    if (~p1_half_done) begin //if up not done
                        if (p1_frame >= (P1_JUMP_FRAMES - 1)) begin
                            p1_half_done = 1;
                            p1_frame <= P1_JUMP_FRAMES -1;
                        end else begin
                            p1_frame <= p1_frame + 1;
                        end
                    end else begin
                        if (p1_frame <= 0) begin
                            p1_half_done = 0;
                            p1_frame <= 0;
                            p1_y <= GROUND_LEVEL;
                        end else begin
                            p1_frame <= p1_frame - 1;
                        end
                    end
                end
            end
            JUMP_PUNCH: begin
                //x coordinate: 
                if (p1_dir == RIGHT) begin
                    if (p1_x < (GAME_W - SPRITE_W)) begin p1_x <= p1_x + JUMP_SPEED_X; end //change logic
                end else begin 
                    if (p1_x > 0) begin p1_x <= p1_x - JUMP_SPEED_X; end //change logic
                end 
                
                if (~p1_half_done) begin
                    p1_y <= p1_y - JUMP_SPEED_Y;
                end else begin
                    p1_y <= p1_y + JUMP_SPEED_Y;
                end
                //animation
                anim_timer1 <= anim_timer1 + 1;
                if (anim_timer1 >= ((p1_frame == (P1_JUMP_PUNCH_FRAMES - 1)) ? 11 : 4)) begin
                    anim_timer1 <= 0;
                    if (~p1_half_done) begin //if up not done
                        if (p1_frame >= (P1_JUMP_PUNCH_FRAMES - 1)) begin
                            p1_half_done = 1;
                            p1_frame <= P1_JUMP_PUNCH_FRAMES -1;
                        end else begin
                            p1_frame <= p1_frame + 1;
                        end
                    end else begin
                        if (p1_frame <= 0) begin
                            p1_half_done = 0;
                            p1_frame <= 0;
                            p1_y <= GROUND_LEVEL;
                            //p1_state <= IDLE; change
                        end else begin
                            p1_frame <= p1_frame - 1;
                        end
                    end
                end
            end
            GOT_HIT: begin
                anim_timer1 <= anim_timer1 + 1;
                if (anim_timer1 >= (20/(2*GOT_HIT_FRAMES)-1)) begin
                    anim_timer1 <= 0;
                    if (~p1_half_done) begin //if throw not done
                        if (p1_frame >= (GOT_HIT_FRAMES - 1)) begin
                            p1_half_done = 1;
                            p1_frame <= GOT_HIT_FRAMES -1;
                        end else begin
                            p1_frame <= p1_frame + 1;
                        end
                    end else begin
                        if (p1_frame <= 0) begin
                            p1_half_done = 0;
                            p1_frame <= 0;
                        end else begin
                            p1_frame <= p1_frame - 1;
                        end
                    end
                end
            end
            LOSE: begin
                //update coordinates 
                if (p1_dir == RIGHT && p1_frame != LOSE_FRAMES - 1) begin p1_x <= p1_x - LOSE_SPEED; end
                else if (p1_dir == LEFT && p1_frame != LOSE_FRAMES - 1) begin p1_x <= p1_x + LOSE_SPEED; end
	

                anim_timer1 <= anim_timer1 + 1;

                if (anim_timer1 >= (50/LOSE_FRAMES - 1)) begin 
                    anim_timer1 <= 0;
                    if (p1_frame >= (LOSE_FRAMES - 1)) begin
                        //p1_frame <= LOSE_FRAMES - 1;
								p1_x <= 10'd10;
								p1_frame <= 0;
                    end else 
                        p1_frame <= p1_frame + 1;
                end
            end
            WIN: begin
                anim_timer1 <= anim_timer1 + 1;
                if (anim_timer1 >= (180/WIN_FRAMES - 1)) begin
                    anim_timer1 <= 0;
                    if (p1_frame >= (WIN_FRAMES - 1)) 
                        p1_frame <= 1;
                    else 
                        p1_frame <= p1_frame + 1'b1;
                end
            end
        endcase
        case(p2_state)
            IDLE: begin
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
                if (p2_dir == RIGHT) begin p2_x <= p2_x + WALK_SPEED; end
                else begin p2_x <= p2_x - WALK_SPEED; end

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
                            p2_half_done = 1;
                            p2_frame <= PUNCH_FRAMES -1;
                        end else begin
                            p2_frame <= p2_frame + 1;
                        end
                    end else begin
                        if (p2_frame <= 0) begin
                            p2_half_done = 0;
                            p2_frame <= 0;
                            //p2_state <= IDLE;
                        end else begin
                            p2_frame <= p2_frame - 1;
                        end
                    end
                end
            end
            JUMP: begin
                //x coordinate: 
                if (p2_dir == RIGHT) begin
                    if (p2_x < (GAME_W - SPRITE_W)) begin p2_x <= p2_x + JUMP_SPEED_X; end //change logic
                end else begin 
                    if (p2_x > 0) begin p2_x <= p2_x - JUMP_SPEED_X; end //change logic
                end 
                
                if (~p2_half_done) begin
                    p2_y <= p2_y - JUMP_SPEED_Y;
                end else begin
                    p2_y <= p2_y + JUMP_SPEED_Y;
                end
                //animation
                anim_timer2 <= anim_timer2 + 1;
                if (anim_timer2 >= ((p2_frame == (P2_JUMP_FRAMES - 1)) ? 11 : 3)) begin
                    anim_timer2 <= 0;
                    if (~p2_half_done) begin //if up not done
                        if (p2_frame >= (P2_JUMP_FRAMES - 1)) begin
                            p2_half_done = 1;
                            p2_frame <= P2_JUMP_FRAMES -1;
                        end else begin
                            p2_frame <= p2_frame + 1;
                        end
                    end else begin
                        if (p2_frame <= 0) begin
                            p2_half_done = 0;
                            p2_frame <= 0;
                            p2_y <= GROUND_LEVEL;
                        end else begin
                            p2_frame <= p2_frame - 1;
                        end
                    end
                end
            end
            JUMP_PUNCH: begin
                //x coordinate: 
                if (p2_dir == RIGHT) begin
                    if (p2_x < (GAME_W - SPRITE_W)) begin p2_x <= p2_x + JUMP_SPEED_X; end //change logic
                end else begin 
                    if (p2_x > 0) begin p2_x <= p2_x - JUMP_SPEED_X; end //change logic
                end 
                
                if (~p2_half_done) begin
                    p2_y <= p2_y - JUMP_SPEED_Y;
                end else begin
                    p2_y <= p2_y + JUMP_SPEED_Y;
                end
                //animation
                anim_timer2 <= anim_timer2 + 1;
                if (anim_timer2 >= ((p2_frame == (P2_JUMP_PUNCH_FRAMES - 1)) ? 10 : 2)) begin
                    anim_timer2 <= 0;
                    if (~p2_half_done) begin //if up not done
                        if (p2_frame >= (P2_JUMP_PUNCH_FRAMES - 1)) begin
                            p2_half_done = 1;
                            p2_frame <= P2_JUMP_PUNCH_FRAMES -1;
                        end else begin
                            p2_frame <= p2_frame + 1;
                        end
                    end else begin
                        if (p2_frame <= 0) begin
                            p2_half_done = 0;
                            p2_frame <= 0;
                            p2_y <= GROUND_LEVEL;
                        end else begin
                            p2_frame <= p2_frame - 1;
                        end
                    end
                end
            end
            GOT_HIT: begin
                anim_timer2 <= anim_timer2 + 1;
                if (anim_timer2 >= (20/(2*GOT_HIT_FRAMES)-1)) begin
                    anim_timer2 <= 0;
                    if (~p2_half_done) begin //if throw not done
                        if (p2_frame >= (GOT_HIT_FRAMES - 1)) begin
                            p2_half_done = 1;
                            p2_frame <= GOT_HIT_FRAMES -1;
                        end else begin
                            p2_frame <= p2_frame + 1;
                        end
                    end else begin
                        if (p2_frame <= 0) begin
                            p2_half_done = 0;
                            p2_frame <= 0;
                            //p2_state <= IDLE;
                        end else begin
                            p2_frame <= p2_frame - 1;
                        end
                    end
                end
            end
            LOSE: begin
                //update coordinates 
                if (p2_dir == RIGHT && p2_frame != LOSE_FRAMES - 1) begin p2_x <= p2_x - LOSE_SPEED; end
                else if (p2_dir == LEFT && p2_frame != LOSE_FRAMES - 1) begin p2_x <= p2_x + LOSE_SPEED; end

                anim_timer2 <= anim_timer2 + 1;

                if (anim_timer2 >= (50/LOSE_FRAMES - 1)) begin 
                    anim_timer2 <= 0;
                    if (p2_frame >= (LOSE_FRAMES - 1)) begin
                        p2_frame <= LOSE_FRAMES - 1;
								p2_x <= 10'd65;
                    end else 
                        p2_frame <= p2_frame + 1;
                end
            end
            WIN: begin
                anim_timer2 <= anim_timer2 + 1;
                if (anim_timer2 >= (180/WIN_FRAMES - 1)) begin
                    anim_timer2 <= 0;
                    if (p2_frame >= (WIN_FRAMES - 1)) 
                        p2_frame <= 1;
                    else 
                        p2_frame <= p2_frame + 1'b1;
                end
            end
        endcase
    end

    //ROM WIRES declaration
    wire [16:0] p1_rom_addr, p2_rom_addr; //change bits
    wire [14:0] bg_rom_addr, elem_rom_addr;
    wire [7:0] bg_rom_data, p1_rom_data, p2_rom_data, elem_rom_data;

    //HARDWARE ROM declaration
    p1_rom player1_memory (.address(p1_rom_addr), .clock(CLOCK_50), .q(p1_rom_data));
    p2_rom player2_memory (.address(p2_rom_addr), .clock(CLOCK_50), .q(p2_rom_data));
    bg_rom background_memory (.address(bg_rom_addr), .clock(CLOCK_50), .q(bg_rom_data));
    elem_rom element_memory (.address(elem_rom_addr), .clock(CLOCK_50), .q(elem_rom_data));

    //call graphics, TODO: ensure inputs are all right
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


// For actual game logic
    assign p1_incoming_damage_val = p2_outgoing_damage_val;
    assign p2_incoming_damage_val = p1_outgoing_damage_val;

    // Testing logic FPGA connection / not needed in actual game
    assign p1_punch_cmd    =   ~KEY[1];
	assign p1_h_move	=   ~KEY[2] && SW[17:16];
    assign p1_jump_cmd    =   ~KEY[3];
    assign p1_punch_val =   SW[3:0];
    assign p1_charging = 1'b0;
    assign p1_charge = 6'b0;

    assign p2_punch_cmd = 1'b0;
    assign p2_h_move = 2'b00; // P2 stands still
    assign p2_jump_cmd = 1'b0;
    assign p2_punch_val = 0;
    assign p2_charging = 1'b0;
    assign p2_charge = 6'b0;

    game_engine game(
        .clk(CLOCK_50), 
        .rst(~KEY[0]), 
        .p1_ready(p1_start_button), 
        .p2_ready(p2_start_button), 
        .restart_cmd(rematch_button_wire),
        .p1_hp(p1_hp), 
        .p2_hp(p2_hp), 
        .game_state_out(game_state), 
        .round_reset(start_new_round_wire), 
        .match_over(match_over), 
        .p1_winner(p1_winner), 
        .p2_winner(p2_winner),
        .time_left(time_left)
   );

    player_controller #(.START_X(p1_start_x), .START_FACING(1)) p1(
        .clk(CLOCK_50), 
        .reset(start_new_round_wire), 
        .h_move_cmd(p1_h_move),
        .jump_cmd(p1_jump_cmd), 
        .punch_cmd(p1_punch_cmd), 
        .punch_val(p1_punch_val),
        .H_speed(WALK_SPEED),
        .powerUp_cmd(p1_charging), 
        .powerUp_val(p1_charge), 
        .take_hit_pulse(p2_hit_p1),
        .incoming_damage_val(p1_incoming_damage_val),
        .pos_x(p1_x), 
        .pos_y(p1_y),
        .facing_right(p1_dir), 
        .hp(p1_hp), 
        .is_punching(p1_is_punching),
        .is_dead(p1_dead), 
        .outgoing_damage_val(p1_outgoing_damage_val), 
        .sprite_state(p1_state), 
        .play_en(game_state == 2'd1),
        .opponent_x(p2_x), 
        .is_move_left(p1_is_move_left), 
        .is_move_right(p1_is_move_right), 
        .is_jumping(p1_is_jumping), 
        .player(0),
        .match_over(match_over), 
        .i_won(p1_winner)
   );

    player_controller #(.START_X(p2_start_x), .START_FACING(0)) p2(
        .clk(CLOCK_50), 
        .reset(start_new_round_wire), 
        .h_move_cmd(p2_h_move),
        .jump_cmd(p2_jump_cmd), 
        .punch_cmd(p2_punch_cmd), 
        .punch_val(p2_punch_val),
        .H_speed(WALK_SPEED),
        .powerUp_cmd(p2_charging), 
        .powerUp_val(p2_charge), 
        .take_hit_pulse(p1_hit_p2),
        .incoming_damage_val(p2_incoming_damage_val), 
        .pos_x(p2_x), .pos_y(p2_y),
        .facing_right(p2_dir), 
        .hp(p2_hp), 
        .is_punching(p2_is_punching),
        .is_dead(p2_dead), 
        .outgoing_damage_val(p2_outgoing_damage_val), 
        .sprite_state(p2_state), 
        .play_en(game_state == 2'd1),
        .opponent_x(p1_x), 
        .is_move_left(p2_is_move_left), 
        .is_move_right(p2_is_move_right), 
        .is_jumping(p2_is_jumping), 
        .player(1),
        .match_over(match_over), 
        .i_won(p2_winner)
    );

    collision_unit collision(
       .p1_x(p1_x), 
       .p1_y(p1_y), 
       .p2_x(p2_x), 
       .p2_y(p2_y),
       .p1_punching(p1_is_punching), 
       .p2_punching(p2_is_punching),
       .p1_dir(p1_dir), 
       .p2_dir(p2_dir),
       .p1_is_jumping(p1_is_jumping), 
       .p2_is_jumping(p2_is_jumping),
       .p1_hit_p2(p1_hit_p2), 
       .p2_hit_p1(p2_hit_p1)
   );
endmodule
