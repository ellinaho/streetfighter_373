//x coordinate: walk
if (p1_dir == RIGHT) begin
    if ((p1_x + 10'd64 - 10'd15) < 10'd160) begin p1_x <= p1_x + WALK_SPEED; end 
end else begin 
    if ((p1_x + 10'd15) > 0 && (p1_x + 10'd15) < 10'd512) begin p1_x <= p1_x - WALK_SPEED; end 
end

//jump and jumppunch
if (p1_dir == RIGHT) begin
    if ((p1_x + 10'd64 - 10'd15) < 10'd160) begin p1_x <= p1_x + JUMP_SPEED_X; end 
end else begin 
    if ((p1_x + 10'd15) > 0 && (p1_x + 10'd15) < 10'd512) begin p1_x <= p1_x - JUMP_SPEED_X; end 
end

