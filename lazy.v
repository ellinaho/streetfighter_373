else if (move_cmd == 2'b01 && (my_hurtbox_right + H_speed < MAX_WIDTH)) begin
    player_state <= WALK;
end
else if (move_cmd == 2'b10 && (my_hurtbox_left > H_speed && my_hurtbox_left < 512)) begin
    player_state <= WALK;
end


// Going Left
    else if (move_cmd == 2'b10) begin
        // 1. First check if we have hit the wall (WITH UNDERFLOW PROTECTION)
        if (my_hurtbox_left > H_speed && my_hurtbox_left < 512) begin

WALK: begin
    //update coordinates 
    if (p1_dir == RIGHT) begin 
        if ((p1_x + SPRITE_W - 15) < GAME_W) p1_x <= p1_x + WALK_SPEED;
    end else begin 
        if ((p1_x + 15) > 0 && (p1_x + 15) < 512) p1_x <= p1_x - WALK_SPEED;
    end
    // ... (leave animation timer alone)