module collision_unit(
    input wire [9:0] p1_x, p1_y,
    input wire [9:0] p2_x, p2_y,
    input wire p1_punching, p2_punching,
    input wire p1_kicking, p2_kicking,
    input wire p1_facing_right, p2_facing_right,
    output wire p1_hit_p2_upper, p1_hit_p2_lower, p2_hit_p1_upper, p2_hit_p1_lower
);

    localparam PLAYER_WIDTH = 10'd20;
    localparam PLAYER_HEIGHT = 10'd40;

    // // defining the hurt box
    // wire p2_hurtbox_xmin = p2_x;
    // wire p2_hurtbox_xmax = p2_x + 20;

    // wire p1_hurtbox_xmin = p1_x;
    // wire p1_hurtbox_xmax = p1_x + 20;

    // defining the hitbox
    wire [9:0] p1_fist_x = p1_facing_right ? (p1_x + 20) : (p1_x - 10);
    wire [9:0] p1_fist_y_upper = p1_y + 10; // punches
    wire [9:0] p1_fist_y_lower = p1_y + 30; // kicks

    wire [9:0] p2_fist_x = p2_facing_right ? (p2_x + 20) : (p2_x - 10);
    wire [9:0] p2_fist_y_upper = p2_y + 10; // punches
    wire [9:0] p2_fist_y_lower = p2_y + 30; // kicks

    // checking for overlap
    // assign p1_hit_p2_upper = p1_punching && 
    //                    (p1_fist_x >= p2_hurtbox_xmin && p1_fist_x <= p2_hurtbox_xmax) &&
    //                    (p1_fist_y >= p2_y && p1_fist_y <= p2_y + 40);

    // assign p1_hit_p2_lower = p1_kicking && 
    //                    (p1_fist_x >= p2_hurtbox_xmin && p1_fist_x <= p2_hurtbox_xmax) &&
    //                    (p1_fist_y <= p2_y && p1_fist_y >= p2_y - 40);

    // assign p2_hit_p1_upper = p2_punching && 
    //                    (p2_fist_x >= p1_hurtbox_xmin && p2_fist_x <= p1_hurtbox_xmax) &&
    //                    (p2_fist_y >= p1_y && p2_fist_y <= p1_y + 40);

    // assign p2_hit_p1_lower = p2_punching && 
    //                    (p2_fist_x >= p1_hurtbox_xmin && p2_fist_x <= p1_hurtbox_xmax) &&
    //                    (p2_fist_y <= p1_y && p2_fist_y >= p1_y - 40);

    wire p1_in_p2_x = (p1_fist_x >= p2_x && p1_fist_x <= p2_x + PLAYER_WIDTH);

    assign p1_hit_p2_upper = p1_in_p2_x &&
                        ((p1_punching &&
                       (p1_fist_y_upper >= p2_y && p1_fist_y_upper <= p2_y + PLAYER_HEIGHT / 2)) ||
                        (p1_kicking &&
                       (p1_fist_y_lower >= p2_y && p1_fist_y_lower <= p2_y + PLAYER_HEIGHT / 2)));

    assign p1_hit_p2_lower = p1_in_p2_x && 
                        ((p1_punching &&
                       (p1_fist_y_upper >= p2_y + PLAYER_HEIGHT / 2 && p1_fist_y_upper <= p2_y + PLAYER_HEIGHT)) ||
                        (p1_kicking &&
                       (p1_fist_y_lower >= p2_y + PLAYER_HEIGHT / 2 && p1_fist_y_lower <= p2_y + PLAYER_HEIGHT)));

    wire p2_in_p1_x = (p2_fist_x >= p1_x && p2_fist_x <= p1_x + PLAYER_WIDTH);

    assign p2_hit_p1_upper = p2_in_p1_x && 
                        ((p2_punching &&
                       (p2_fist_y_upper >= p1_y && p2_fist_y_upper <= p1_y + PLAYER_HEIGHT / 2)) ||
                        (p2_kicking &&
                       (p2_fist_y_lower >= p1_y && p2_fist_y_lower <= p1_y + PLAYER_HEIGHT / 2)));
    
    assign p2_hit_p1_lower = p2_in_p1_x && 
                        ((p2_punching &&
                       (p2_fist_y_upper >= p1_y + PLAYER_HEIGHT / 2 && p2_fist_y_upper <= p1_y + PLAYER_HEIGHT)) ||
                        (p2_kicking &&
                       (p2_fist_y_lower >= p1_y + PLAYER_HEIGHT / 2 && p2_fist_y_lower <= p1_y + PLAYER_HEIGHT)));

endmodule