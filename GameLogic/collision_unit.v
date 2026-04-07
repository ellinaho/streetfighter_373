// // module collision_unit(
// //     input wire [9:0] p1_x, p1_y,
// //     input wire [9:0] p2_x, p2_y,
// //     input wire p1_punching, p2_punching,
// //     // input wire p1_kicking, p2_kicking,
// //     input wire p1_facing_right, p2_facing_right,
// //     output wire p1_hit_p2_upper, p1_hit_p2_lower, p2_hit_p1_upper, p2_hit_p1_lower
// // );

// //     localparam PLAYER_WIDTH = 10'd20;
// //     localparam PLAYER_HEIGHT = 10'd40;

// //     // // defining the hurt box
// //     // wire p2_hurtbox_xmin = p2_x;
// //     // wire p2_hurtbox_xmax = p2_x + 20;

// //     // wire p1_hurtbox_xmin = p1_x;
// //     // wire p1_hurtbox_xmax = p1_x + 20;

// //     // defining the hitbox
// //     wire [9:0] p1_fist_x = p1_facing_right ? (p1_x + 20) : (p1_x - 10);
// //     wire [9:0] p1_fist_y_upper = p1_y + 10; // punches
// //     // wire [9:0] p1_fist_y_lower = p1_y + 30; // kicks

// //     wire [9:0] p2_fist_x = p2_facing_right ? (p2_x + 20) : (p2_x - 10);
// //     wire [9:0] p2_fist_y_upper = p2_y + 10; // punches
// //     // wire [9:0] p2_fist_y_lower = p2_y + 30; // kicks

// //     // checking for overlap
// //     // assign p1_hit_p2_upper = p1_punching && 
// //     //                    (p1_fist_x >= p2_hurtbox_xmin && p1_fist_x <= p2_hurtbox_xmax) &&
// //     //                    (p1_fist_y >= p2_y && p1_fist_y <= p2_y + 40);

// //     // assign p1_hit_p2_lower = p1_kicking && 
// //     //                    (p1_fist_x >= p2_hurtbox_xmin && p1_fist_x <= p2_hurtbox_xmax) &&
// //     //                    (p1_fist_y <= p2_y && p1_fist_y >= p2_y - 40);

// //     // assign p2_hit_p1_upper = p2_punching && 
// //     //                    (p2_fist_x >= p1_hurtbox_xmin && p2_fist_x <= p1_hurtbox_xmax) &&
// //     //                    (p2_fist_y >= p1_y && p2_fist_y <= p1_y + 40);

// //     // assign p2_hit_p1_lower = p2_punching && 
// //     //                    (p2_fist_x >= p1_hurtbox_xmin && p2_fist_x <= p1_hurtbox_xmax) &&
// //     //                    (p2_fist_y <= p1_y && p2_fist_y >= p1_y - 40);

// //     wire p1_in_p2_x = (p1_fist_x >= p2_x && p1_fist_x <= p2_x + PLAYER_WIDTH);

// //     assign p1_hit_p2_upper = p1_in_p2_x &&
// //                         ((p1_punching &&
// //                        (p1_fist_y_upper >= p2_y && p1_fist_y_upper <= p2_y + PLAYER_HEIGHT / 2)) ||
// //                         // (p1_kicking &&
// //                        ((p1_fist_y_lower >= p2_y && p1_fist_y_lower <= p2_y + PLAYER_HEIGHT / 2)));

// //     assign p1_hit_p2_lower = p1_in_p2_x && 
// //                         ((p1_punching &&
// //                        (p1_fist_y_upper >= p2_y + PLAYER_HEIGHT / 2 && p1_fist_y_upper <= p2_y + PLAYER_HEIGHT)) ||
// //                         // (p1_kicking &&
// //                        ((p1_fist_y_lower >= p2_y + PLAYER_HEIGHT / 2 && p1_fist_y_lower <= p2_y + PLAYER_HEIGHT)));

// //     wire p2_in_p1_x = (p2_fist_x >= p1_x && p2_fist_x <= p1_x + PLAYER_WIDTH);

// //     assign p2_hit_p1_upper = p2_in_p1_x && 
// //                         ((p2_punching &&
// //                        (p2_fist_y_upper >= p1_y && p2_fist_y_upper <= p1_y + PLAYER_HEIGHT / 2)) ||
// //                         // (p2_kicking &&
// //                        ((p2_fist_y_lower >= p1_y && p2_fist_y_lower <= p1_y + PLAYER_HEIGHT / 2)));
    
// //     assign p2_hit_p1_lower = p2_in_p1_x && 
// //                         ((p2_punching &&
// //                        (p2_fist_y_upper >= p1_y + PLAYER_HEIGHT / 2 && p2_fist_y_upper <= p1_y + PLAYER_HEIGHT)) ||
// //                         // (p2_kicking &&
// //                        ((p2_fist_y_lower >= p1_y + PLAYER_HEIGHT / 2 && p2_fist_y_lower <= p1_y + PLAYER_HEIGHT)));

// // endmodule

// module collision_unit(
//     input wire [9:0] p1_x, p1_y,          // Top-Left corner of P1
//     input wire [9:0] p2_x, p2_y,          // Top-Left corner of P2
//     input wire p1_punching, p2_punching,  // Is the attack active?
//     input wire p1_facing_right, p2_facing_right, // Which way are they looking?
    
//     // Unified Hit Outputs (No more upper/lower)
//     output wire p1_hit_p2, 
//     output wire p2_hit_p1  
// );

//     // Bounding Box Dimensions
//     localparam PLAYER_WIDTH  = 10'd20;
//     localparam PLAYER_HEIGHT = 10'd40;

//     // ========================================================================
//     // 1. AABB OVERLAP CHECK (Are the two sprite boxes touching?)
//     // ========================================================================
//     // For X: P1's left edge is left of P2's right edge, AND P1's right edge is right of P2's left edge
//     wire overlap_x = (p1_x < p2_x + PLAYER_WIDTH) && (p1_x + PLAYER_WIDTH > p2_x);
    
//     // For Y: P1's top edge is above P2's bottom edge, AND P1's bottom edge is below P2's top edge
//     // (Remember: In VGA, Y increases as you go down the screen)
//     wire overlap_y = (p1_y < p2_y + PLAYER_HEIGHT) && (p1_y + PLAYER_HEIGHT > p2_y);
    
//     // They are physically touching if both X and Y overlap
//     wire touching = overlap_x && overlap_y;

//     // ========================================================================
//     // 2. DIRECTION CHECK (No hitting backward!)
//     // ========================================================================
//     // Even if touching, P1 shouldn't hit P2 if P1's back is turned.
//     // If P1 faces right (1), P1's x must be <= P2's x. If facing left (0), P1's x must be >= P2's x.
//     wire p1_facing_p2 = p1_facing_right ? (p1_x <= p2_x) : (p1_x >= p2_x);
//     wire p2_facing_p1 = p2_facing_right ? (p2_x <= p1_x) : (p2_x >= p1_x);

//     // ========================================================================
//     // 3. FINAL HIT CALCULATION
//     // ========================================================================
//     // A successful hit requires ALL three conditions to be true:
//     // 1. The boxes are touching
//     // 2. The player is throwing a punch
//     // 3. The player is actually facing their opponent
    
//     assign p1_hit_p2 = touching && p1_punching && p1_facing_p2;
//     assign p2_hit_p1 = touching && p2_punching && p2_facing_p1;

// endmodule

module collision_unit(
    input wire [9:0] p1_x, p1_y,          // Top-Left corner of P1
    input wire [9:0] p2_x, p2_y,          // Top-Left corner of P2
    input wire p1_punching, p2_punching,  // Is the attack active?
    input wire p1_facing_right, p2_facing_right, // Which way are they looking?
    
    // Unified Hit Outputs (No more upper/lower)
    output wire p1_hit_p2, 
    output wire p2_hit_p1  
);

    // Hurtbox: The player's physical body (vulnerable area)
    localparam HURTBOX_W = 10'd20;
    localparam HURTBOX_H = 10'd40;

    // Hitbox: The actual punch (deals damage)
    localparam HITBOX_W  = 10'd15; // How far the punch reaches
    localparam HITBOX_H  = 10'd10; // How "thick" the punch is
    localparam HITBOX_Y_OFFSET = 10'd10; // Spawns the punch at upper-body height

    // Dynamic hibox placement
    // --- P1 HITBOX ---
    wire [9:0] p1_hitbox_left = p1_facing_right ? (p1_x + HURTBOX_W) : 
                                ((p1_x > HITBOX_W) ? (p1_x - HITBOX_W) : 10'd0);
    wire [9:0] p1_hitbox_right = p1_hitbox_left + HITBOX_W;
    wire [9:0] p1_hitbox_top = p1_y + HITBOX_Y_OFFSET;
    wire [9:0] p1_hitbox_bottom = p1_hitbox_top + HITBOX_H;

    // --- P2 HITBOX ---
    wire [9:0] p2_hitbox_left = p2_facing_right ? (p2_x + HURTBOX_W) : 
                                ((p2_x > HITBOX_W) ? (p2_x - HITBOX_W) : 10'd0);
    wire [9:0] p2_hitbox_right = p2_hitbox_left + HITBOX_W;
    wire [9:0] p2_hitbox_top = p2_y + HITBOX_Y_OFFSET;
    wire [9:0] p2_hitbox_bottom = p2_hitbox_top + HITBOX_H;

    // Hurtbox Placement
    // --- P1 HURTBOX ---
    wire [9:0] p1_hurtbox_left = p1_x;
    wire [9:0] p1_hurtbox_right = p1_x + HURTBOX_W;
    wire [9:0] p1_hurtbox_top = p1_y;
    wire [9:0] p1_hurtbox_bottom = p1_y + HURTBOX_H;

    // --- P2 HURTBOX ---
    wire [9:0] p2_hurtbox_left = p2_x;
    wire [9:0] p2_hurtbox_right = p2_x + HURTBOX_W;
    wire [9:0] p2_hurtbox_top = p2_y;
    wire [9:0] p2_hurtbox_bottom = p2_y + HURTBOX_H;

    // Hitbox vs Hurtbox Collision Logic
    wire p1_punch_hits_x = (p1_hitbox_left < p2_hurtbox_right) && (p1_hitbox_right > p2_hurtbox_left);
    wire p1_punch_hits_y = (p1_hitbox_top < p2_hurtbox_bottom) && (p1_hitbox_bottom > p2_hurtbox_top);
    
    assign p1_hit_p2 = p1_punching && p1_punch_hits_x && p1_punch_hits_y;

    // --- P2 Attacking P1 ---
    wire p2_punch_hits_x = (p2_hitbox_left < p1_hurtbox_right) && (p2_hitbox_right > p1_hurtbox_left);
    wire p2_punch_hits_y = (p2_hitbox_top < p1_hurtbox_bottom) && (p2_hitbox_bottom > p1_hurtbox_top);
    
    assign p2_hit_p1 = p2_punching && p2_punch_hits_x && p2_punch_hits_y;

    // // Bounding Box Dimensions
    // localparam PLAYER_WIDTH  = 10'd20;
    // localparam PLAYER_HEIGHT = 10'd40;

    // // ========================================================================
    // // 1. AABB OVERLAP CHECK (Are the two sprite boxes touching?)
    // // ========================================================================
    // // For X: P1's left edge is left of P2's right edge, AND P1's right edge is right of P2's left edge
    // wire overlap_x = (p1_x < p2_x + PLAYER_WIDTH) && (p1_x + PLAYER_WIDTH > p2_x);
    
    // // For Y: P1's top edge is above P2's bottom edge, AND P1's bottom edge is below P2's top edge
    // // (Remember: In VGA, Y increases as you go down the screen)
    // wire overlap_y = (p1_y < p2_y + PLAYER_HEIGHT) && (p1_y + PLAYER_HEIGHT > p2_y);
    
    // // They are physically touching if both X and Y overlap
    // wire touching = overlap_x && overlap_y;

    // // ========================================================================
    // // 2. DIRECTION CHECK (No hitting backward!)
    // // ========================================================================
    // // Even if touching, P1 shouldn't hit P2 if P1's back is turned.
    // // If P1 faces right (1), P1's x must be <= P2's x. If facing left (0), P1's x must be >= P2's x.
    // wire p1_facing_p2 = p1_facing_right ? (p1_x <= p2_x) : (p1_x >= p2_x);
    // wire p2_facing_p1 = p2_facing_right ? (p2_x <= p1_x) : (p2_x >= p1_x);

    // // ========================================================================
    // // 3. FINAL HIT CALCULATION
    // // ========================================================================
    // // A successful hit requires ALL three conditions to be true:
    // // 1. The boxes are touching
    // // 2. The player is throwing a punch
    // // 3. The player is actually facing their opponent
    
    // assign p1_hit_p2 = touching && p1_punching && p1_facing_p2;
    // assign p2_hit_p1 = touching && p2_punching && p2_facing_p1;

endmodule

