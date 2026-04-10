reg prev_jump_cmd;
reg prev_punch_cmd;
reg prev_charge_cmd;

wire jump_trig   = jump_cmd && !prev_jump_cmd;
wire punch_trig  = punch_cmd && !prev_punch_cmd;
wire charge_trig = charge_cmd && !prev_charge_cmd;

prev_jump_cmd <= jump_cmd;
prev_punch_cmd <= punch_cmd;
prev_charge_cmd <= charge_cmd;

Now go through your player_controller.v state machine and 
replace jump_cmd with jump_trig, punch_cmd with punch_trig, 
and charge_cmd with charge_trig in your IDLE and WALK transitions!

case(p1_state)
    IDLE: begin
        p1_y <= GROUND_LEVEL; // FORCE GRAVITY
        anim_timer1 <= anim_timer1 + 1;
        // ...
    WALK: begin
        p1_y <= GROUND_LEVEL; // FORCE GRAVITY
        // ...



// Inside IDLE state:
else if (move_cmd == 2'b01) begin
    // Check Right Wall AND Opponent!
    if ((my_hurtbox_right + H_speed < MAX_WIDTH) && 
        !((opp_hurtbox_left > my_hurtbox_left) && (my_hurtbox_right + H_speed + MIN_DIST > opp_hurtbox_left))) begin
        player_state <= WALK;
    end
end
else if (move_cmd == 2'b10) begin
    // Check Left Wall AND Opponent!
    if ((my_hurtbox_left > H_speed && my_hurtbox_left < 512) && 
        !((my_hurtbox_left > opp_hurtbox_left) && (opp_hurtbox_right + H_speed + MIN_DIST > my_hurtbox_left))) begin
        player_state <= WALK;
    end
end


localparam [25:0] GOT_HIT_TIME    = 26'd60_000_000; // Increased to 1.2 seconds of immunity