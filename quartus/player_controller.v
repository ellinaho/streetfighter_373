module player_controller#(
	parameter player_num = 0
)(
    input CLOCK_50,

    //from game engine
    input wire [1:0] game_state,
    input [1:0] winner,
  
    //spi inputs 
    input wire [1:0] move_cmd, 
    input wire       jump_cmd,
    input wire       punch_cmd,
    input wire       charge_cmd,

    //from collision
    input wire       getting_hit,
	 input wire 		hit_success,

    //from...itself...
    input wire [6:0] damage_val_in,

    //from fpga/vga 
    input wire [9:0] opponent_x, // Where is the other player's sprite box?
    input wire [9:0] pos_x,
    input wire [9:0] pos_y, 
    input wire [3:0] frame, 
    input wire half_done,
  
    //to game_top, collision
    output reg       player_dir,
    output reg [3:0]  player_state,

    //to game engine, game_top
    output reg [6:0] hp,
    output reg is_charging,
    output reg [4:0] charge_bar, //out of 25 to go to vga
    output reg full_charge,
    
    //to itself
    output wire [6:0] damage_val_out
);
    initial begin
        player_dir = ~player_num;
        player_state = 0;
        hp         = 7'd50;
        is_charging = 0;
        charge_bar = 0;
        full_charge = 0;
    end

    localparam MAX_WIDTH = 10'd160;
    localparam MIN_DIST = 10'd5; // Pushbox distance between HURTBOX edges

    parameter IDLE = 0, WALK = 1, PUNCH = 2, JUMP = 3; 
    parameter JUMP_PUNCH = 4, GOT_HIT = 5, LOSE = 6, WIN = 7;

    reg [25:0] action_timer;
    localparam [25:0] PUNCH_TIME      = 26'd16_000_000;
    localparam [25:0] GOT_HIT_TIME    = 26'd18_000_000;

    //Fixed
	localparam [25:0] JUMP_TIME       = 26'd50_000_000;
    localparam [25:0] JUMP_PUNCH_TIME = 26'd50_000_000;

    localparam START = 0, GAME = 1, KO = 2;

    localparam [22:0] CHARGE_DELAY = 23'd4_999_999; 
    reg [22:0] charge_timer;

    wire H_speed = 1;
    
    localparam [1:0] jump_thresh = 3;

//hurt box stuff and offsets idk
    localparam SPRITE_W = 10'd64;
    localparam SPRITE_H = 10'd53;
    
    // P1 Offsets
    localparam P1_HURTBOX_W = 10'd25;
    localparam P1_OFFSET_X = (SPRITE_W - P1_HURTBOX_W) / 2; // 19
    
    // P2 Offsets
    localparam P2_HURTBOX_W = 10'd22;
    localparam P2_OFFSET_X = (SPRITE_W - P2_HURTBOX_W) / 2; // 21
    
    // Determine exactly which offsets belong to us and which belong to the opponent
    wire [9:0] my_offset_x   = (player_num == 1'b0) ? P1_OFFSET_X  : P2_OFFSET_X;
    wire [9:0] my_hurtbox_w  = (player_num == 1'b0) ? P1_HURTBOX_W : P2_HURTBOX_W;
    
    wire [9:0] opp_offset_x  = (player_num == 1'b0) ? P2_OFFSET_X  : P1_OFFSET_X;
    wire [9:0] opp_hurtbox_w = (player_num == 1'b0) ? P2_HURTBOX_W : P1_HURTBOX_W;
    
    // Calculate the actual left and right boundaries of both physical bodies
    wire [9:0] my_hurtbox_left   = pos_x + my_offset_x;
    wire [9:0] my_hurtbox_right  = my_hurtbox_left + my_hurtbox_w;
    
    wire [9:0] opp_hurtbox_left  = opponent_x + opp_offset_x;
    wire [9:0] opp_hurtbox_right = opp_hurtbox_left + opp_hurtbox_w;

    reg [1:0] prev_state = START;
    
    reg prev_jump_cmd;
    reg prev_punch_cmd;
	 reg prev_charge_cmd = 0;

    wire jump_trig   = jump_cmd && !prev_jump_cmd;
    wire punch_trig  = punch_cmd && !prev_punch_cmd;
	 wire charge_trig = charge_cmd && !prev_charge_cmd;
	 
//state machines
    always @(posedge CLOCK_50) begin
        if (prev_state != START && game_state == START) begin
            player_state <= IDLE;
            hp <= 50;
            action_timer <= 0;
            player_dir <= ~player_num;
            charge_bar <= 0;
            is_charging <= 0;
            full_charge <= 0;
        end
        else if (prev_state == START && game_state == START) begin
            if (is_charging) begin //if currently charging
                if (charge_cmd) begin
                    if (charge_bar < 25) begin
                        // Timer Logic
                        if (charge_timer == CHARGE_DELAY) begin
                            charge_timer <= 23'd0;       // Reset timer
                            charge_bar   <= charge_bar + 1; // Increment bar
                        end else begin
                            charge_timer <= charge_timer + 1'b1; // Keep counting
                        end
                    end else begin
                        full_charge <= 1'b1;
                        charge_timer <= 23'd0; 
                    end
                end else begin
                    charge_timer <= 23'd0;
                end
            end else if (charge_cmd) begin
                is_charging <= 1'b1;
                charge_timer <= 23'd0;
            end
            
        end
        else if (prev_state == START && game_state == GAME) begin
            charge_bar <= 0;
            is_charging <= 0;
            full_charge <= 0;
        end
        else if (game_state == KO) begin
            if (winner == player_num) begin player_state <= WIN; end
            else if (winner == 2'd2) begin player_state <= IDLE; end   
            else begin player_state <= LOSE;   end
        end
        else if (prev_state == GAME && game_state == GAME) begin
            // Hit Stun Priority
            if (getting_hit && (player_state != GOT_HIT)) begin
                if (hp < damage_val_in) begin
                    hp <= 0;
                end else begin
                    hp <= hp - damage_val_in;
                    player_state <= GOT_HIT;  
                    action_timer <= GOT_HIT_TIME; 
                end
            end
            // Normal Game Logic
            else begin
                case (player_state)
                    IDLE: begin
                        if (punch_trig && ~jump_trig) begin
                            player_state <= PUNCH;
                            action_timer <= PUNCH_TIME;
									 is_charging <= 0;
                        end
                        else if (jump_trig && ~punch_trig) begin
                            player_state <= JUMP;
                            action_timer <= JUMP_TIME;
									 is_charging <= 0;
                        end
                        else if (jump_trig && punch_trig) begin
                            player_state <= JUMP_PUNCH;
                            action_timer <= JUMP_PUNCH_TIME;
									 is_charging <= 0;
                        end
                        else if (move_cmd == 2'b01) begin
                            // Check Right Wall AND Opponent!
									 player_dir <= 1;
                            if ((my_hurtbox_right + H_speed < MAX_WIDTH) && 
                                !((opp_hurtbox_left > my_hurtbox_left) && (my_hurtbox_right + H_speed + MIN_DIST > opp_hurtbox_left))) begin
                                player_state <= WALK;
										  is_charging <= 0;
                            end
                        end
                        else if (move_cmd == 2'b10) begin
                                // Check Left Wall AND Opponent!
										  player_dir <= 0;
                                if ((my_hurtbox_left > H_speed && my_hurtbox_left < 512) && 
                                    !((my_hurtbox_left > opp_hurtbox_left) && (opp_hurtbox_right + H_speed + MIN_DIST > my_hurtbox_left))) begin
                                    player_state <= WALK;
												is_charging <= 0;
                                end
                        end
                        else if (is_charging) begin 
                            if (!charge_cmd) begin 
                                is_charging  <= 1'b0;
                                charge_timer <= 23'd0; 
                            end else begin 
                                if (charge_bar >= 5'd25) begin
                                    is_charging  <= 1'b0;
                                    charge_timer <= 23'd0;
                                end else begin
                                    if (charge_timer == CHARGE_DELAY) begin
                                        charge_timer <= 23'd0;           
                                        charge_bar   <= charge_bar + 1'b1; 
                                    end else begin
                                        charge_timer <= charge_timer + 1'b1;
                                    end
                                end
                            end
                        end
                        else if (charge_trig && charge_bar < 5'd25) begin
                            player_state <= IDLE;
                            is_charging  <= 1'b1;
                            charge_timer <= 23'd0; 
                        end
                    end
                    WALK: begin
                        if (punch_trig && ~jump_trig) begin
                            player_state <= PUNCH;
                            action_timer <= PUNCH_TIME;
                        end
                        else if (jump_trig && ~punch_trig) begin
                            player_state <= JUMP;
                            action_timer <= JUMP_TIME;
                        end
                        else if (jump_trig && punch_trig) begin
                            player_state <= JUMP_PUNCH;
                            action_timer <= JUMP_PUNCH_TIME;
                        end
                        // Going Right
                        else if (move_cmd == 2'b01) begin
                            // 1. First check if we have hit the wall
									 player_dir <= 1;
                            if (my_hurtbox_right + H_speed < MAX_WIDTH) begin
                                // 2. Next, check if we are hitting the opponent
                                if ((opp_hurtbox_left > my_hurtbox_left) && (my_hurtbox_right + H_speed + MIN_DIST > opp_hurtbox_left)) begin
                                    player_state <= IDLE; // TOO CLOSE: Blocked by opponent pushbox
                                end
                            end else begin
                                player_state <= IDLE; // TOO CLOSE: Blocked by right wall
                            end
                        end
                            
                        // Going Left
                        else if (move_cmd == 2'b10) begin
                            // 1. First check if we have hit the wall
									 player_dir <= 0;
									 if (my_hurtbox_left > H_speed && my_hurtbox_left < 512) begin
										 if (my_hurtbox_left > H_speed) begin
											  // 2. Next, check if we are hitting the opponent
											  if ((my_hurtbox_left > opp_hurtbox_left) && (opp_hurtbox_right + H_speed + MIN_DIST > my_hurtbox_left)) begin
													player_state <= IDLE; // TOO CLOSE: Blocked by opponent pushbox
											  end
										 end else begin
											  player_state <= IDLE; // TOO CLOSE: Blocked by left wall
										 end
									 end
                        end
                            
                        // Stopped pressing move buttons
                        else if (move_cmd == 2'b00) begin
                            player_state <= IDLE;
                        end
                    end
                    PUNCH: begin
								if (hit_success) charge_bar <= 0;
                        if (action_timer > 0) begin
                            action_timer <= action_timer - 1;
                        end else begin
                            player_state <= IDLE;
                        end
                    end
                    JUMP: begin
                        if (punch_trig && (frame < jump_thresh) && ~half_done) begin
                            player_state <= JUMP_PUNCH;
                            action_timer <= action_timer + 26'd15_000_000;
								end else if (half_done && pos_y >= 10'd62) begin
									 player_state <= IDLE;
									 action_timer  <= 0;
                        end else if (action_timer > 0) begin
                            action_timer <= action_timer - 1;
                        end else begin
                            player_state <= IDLE;
                        end
                    end
                    JUMP_PUNCH: begin
								if (hit_success) charge_bar <= 0;
								if ((half_done && pos_y >= 10'd62) || (action_timer == 0)) begin
									 player_state <= IDLE;
									 action_timer  <= 0;
								end else if (action_timer > 0) begin
                            action_timer <= action_timer - 1;
                        end 
                    end
                    GOT_HIT: begin
                        if (action_timer > 0) begin
                            action_timer <= action_timer - 1;
                        end else begin
                            player_state <= IDLE;
                        end
                    end
                endcase
            end
        end
        
        prev_state <= game_state;
		  prev_jump_cmd <= jump_cmd;
			prev_punch_cmd <= punch_cmd;
			prev_charge_cmd <= charge_cmd;

    end

    assign damage_val_out = (player_state == PUNCH || player_state == JUMP_PUNCH) ?
			(charge_bar > 0) ? (5+(charge_bar/5)) : 5 : 7'd0; 


   // hp 0 to 50
   // muscle 0 to 25


endmodule