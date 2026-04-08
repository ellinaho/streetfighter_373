// // module collision_unit(
// //     input wire [9:0] p1_x, p1_y,
// //     input wire [9:0] p2_x, p2_y,
// //     input wire p1_punching, p2_punching,
// //     // input wire p1_kicking, p2_kicking,
// //     input wire p1_dir, p2_dir,
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
// //     wire [9:0] p1_fist_x = p1_dir ? (p1_x + 20) : (p1_x - 10);
// //     wire [9:0] p1_fist_y_upper = p1_y + 10; // punches
// //     // wire [9:0] p1_fist_y_lower = p1_y + 30; // kicks

// //     wire [9:0] p2_fist_x = p2_dir ? (p2_x + 20) : (p2_x - 10);
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
//     input wire p1_dir, p2_dir, // Which way are they looking?
    
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
//     wire p1_facing_p2 = p1_dir ? (p1_x <= p2_x) : (p1_x >= p2_x);
//     wire p2_facing_p1 = p2_dir ? (p2_x <= p1_x) : (p2_x >= p1_x);

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

// module collision_unit(
//     input wire [9:0] p1_x, p1_y,          // Top-Left corner of P1
//     input wire [9:0] p2_x, p2_y,          // Top-Left corner of P2
//     input wire p1_punching, p2_punching,  // Is the attack active?
//     input wire p1_dir, p2_dir, // Which way are they looking?
    
//     // Unified Hit Outputs (No more upper/lower)
//     output wire p1_hit_p2, 
//     output wire p2_hit_p1  
// );

//     // Sprite size
//     // 64 wide, 53 height

//     // Hurtbox: The player's physical body (vulnerable area)
//     localparam HURTBOX_W = 10'd20;
//     localparam HURTBOX_H = 10'd40;

//     //assume hurtbox in the the center
//     localparam P1_HURTBOX_W = 10'd25;
//     localparam P1_HURTBOX_H = 10'd38;

//     localparam P2_HURTBOX_W = 10'd22;
//     localparam P2_HURTBOX_H = 10'd33;

//     // Hitbox: The actual punch (deals damage)
//     localparam HITBOX_W  = 10'd15; // How far the punch reaches
//     localparam HITBOX_H  = 10'd10; // How "thick" the punch is
//     localparam HITBOX_Y_OFFSET = 10'd10; // Spawns the punch at upper-body height

//     localparam P1_HITBOX_W  = 10'd19; // How far the punch reaches
//     localparam P1_HITBOX_H  = 10'd9; // How "thick" the punch is
//     localparam P1_HITBOX_Y_OFFSET = 10'd17; // Spawns the punch at upper-body height

//     // for jump punching
//     localparam P1_HITBOX_W_JUMP  = 10'd12; // How far the punch reaches
//     localparam P1_HITBOX_H_JUMP  = 10'd10; // How "thick" the punch is
//     localparam P1_HITBOX_Y_OFFSET_JUMP = 10'd34; // Spawns the punch at upper-body height
//     //space from edge to the last part of their punch is 10'd6;

//     localparam P2_HITBOX_W  = 10'd14; // How far the punch reaches
//     localparam P2_HITBOX_H  = 10'd8; // How "thick" the punch is
//     localparam P2_HITBOX_Y_OFFSET = 10'd22; // Spawns the punch at upper-body height

//     // for jump punching
//     localparam P2_HITBOX_W_JUMP  = 10'd13; // How far the punch reaches
//     localparam P2_HITBOX_H_JUMP  = 10'd10; // How "thick" the punch is
//     localparam P2_HITBOX_Y_OFFSET_JUMP = 10'd34; // Spawns the punch at upper-body height
//     //space from edge to the last part of their punch is 10'd7;

//     // Dynamic hibox placement
//     // // --- P1 HITBOX ---
//     // wire [9:0] p1_hitbox_left = p1_dir ? (p1_x + HURTBOX_W) : 
//     //                             ((p1_x > HITBOX_W) ? (p1_x - HITBOX_W) : 10'd0);
//     // wire [9:0] p1_hitbox_right = p1_hitbox_left + HITBOX_W;
//     // wire [9:0] p1_hitbox_top = p1_y + HITBOX_Y_OFFSET;
//     // wire [9:0] p1_hitbox_bottom = p1_hitbox_top + HITBOX_H;

//     // // --- P2 HITBOX ---
//     // wire [9:0] p2_hitbox_left = p2_dir ? (p2_x + HURTBOX_W) : 
//     //                             ((p2_x > HITBOX_W) ? (p2_x - HITBOX_W) : 10'd0);
//     // wire [9:0] p2_hitbox_right = p2_hitbox_left + HITBOX_W;
//     // wire [9:0] p2_hitbox_top = p2_y + HITBOX_Y_OFFSET;
//     // wire [9:0] p2_hitbox_bottom = p2_hitbox_top + HITBOX_H;

//     // --- P1 HITBOX ---
//     wire [9:0] p1_hitbox_left = p1_dir ? (p1_x + P1_HURTBOX_W) : 
//                                 ((p1_x > P1_HITBOX_W) ? (p1_x - P1_HITBOX_W) : 10'd0);
//     wire [9:0] p1_hitbox_right = p1_hitbox_left + P1_HITBOX_W;
//     wire [9:0] p1_hitbox_top = p1_y + HITBOX_Y_OFFSET;
//     wire [9:0] p1_hitbox_bottom = p1_hitbox_top + HITBOX_H;

//     // --- P2 HITBOX ---
//     wire [9:0] p2_hitbox_left = p2_dir ? (p2_x + HURTBOX_W) : 
//                                 ((p2_x > HITBOX_W) ? (p2_x - HITBOX_W) : 10'd0);
//     wire [9:0] p2_hitbox_right = p2_hitbox_left + HITBOX_W;
//     wire [9:0] p2_hitbox_top = p2_y + HITBOX_Y_OFFSET;
//     wire [9:0] p2_hitbox_bottom = p2_hitbox_top + HITBOX_H;

//     // Hurtbox Placement
//     // --- P1 HURTBOX ---
//     wire [9:0] p1_hurtbox_left = p1_x;
//     wire [9:0] p1_hurtbox_right = p1_x + HURTBOX_W;
//     wire [9:0] p1_hurtbox_top = p1_y;
//     wire [9:0] p1_hurtbox_bottom = p1_y + HURTBOX_H;

//     // --- P2 HURTBOX ---
//     wire [9:0] p2_hurtbox_left = p2_x;
//     wire [9:0] p2_hurtbox_right = p2_x + HURTBOX_W;
//     wire [9:0] p2_hurtbox_top = p2_y;
//     wire [9:0] p2_hurtbox_bottom = p2_y + HURTBOX_H;

//     // Hitbox vs Hurtbox Collision Logic
//     wire p1_punch_hits_x = (p1_hitbox_left < p2_hurtbox_right) && (p1_hitbox_right > p2_hurtbox_left);
//     wire p1_punch_hits_y = (p1_hitbox_top < p2_hurtbox_bottom) && (p1_hitbox_bottom > p2_hurtbox_top);
    
//     assign p1_hit_p2 = p1_punching && p1_punch_hits_x && p1_punch_hits_y;

//     // --- P2 Attacking P1 ---
//     wire p2_punch_hits_x = (p2_hitbox_left < p1_hurtbox_right) && (p2_hitbox_right > p1_hurtbox_left);
//     wire p2_punch_hits_y = (p2_hitbox_top < p1_hurtbox_bottom) && (p2_hitbox_bottom > p1_hurtbox_top);
    
//     assign p2_hit_p1 = p2_punching && p2_punch_hits_x && p2_punch_hits_y;

//     // // Bounding Box Dimensions
//     // localparam PLAYER_WIDTH  = 10'd20;
//     // localparam PLAYER_HEIGHT = 10'd40;

//     // // ========================================================================
//     // // 1. AABB OVERLAP CHECK (Are the two sprite boxes touching?)
//     // // ========================================================================
//     // // For X: P1's left edge is left of P2's right edge, AND P1's right edge is right of P2's left edge
//     // wire overlap_x = (p1_x < p2_x + PLAYER_WIDTH) && (p1_x + PLAYER_WIDTH > p2_x);
    
//     // // For Y: P1's top edge is above P2's bottom edge, AND P1's bottom edge is below P2's top edge
//     // // (Remember: In VGA, Y increases as you go down the screen)
//     // wire overlap_y = (p1_y < p2_y + PLAYER_HEIGHT) && (p1_y + PLAYER_HEIGHT > p2_y);
    
//     // // They are physically touching if both X and Y overlap
//     // wire touching = overlap_x && overlap_y;

//     // // ========================================================================
//     // // 2. DIRECTION CHECK (No hitting backward!)
//     // // ========================================================================
//     // // Even if touching, P1 shouldn't hit P2 if P1's back is turned.
//     // // If P1 faces right (1), P1's x must be <= P2's x. If facing left (0), P1's x must be >= P2's x.
//     // wire p1_facing_p2 = p1_dir ? (p1_x <= p2_x) : (p1_x >= p2_x);
//     // wire p2_facing_p1 = p2_dir ? (p2_x <= p1_x) : (p2_x >= p1_x);

//     // // ========================================================================
//     // // 3. FINAL HIT CALCULATION
//     // // ========================================================================
//     // // A successful hit requires ALL three conditions to be true:
//     // // 1. The boxes are touching
//     // // 2. The player is throwing a punch
//     // // 3. The player is actually facing their opponent
    
//     // assign p1_hit_p2 = touching && p1_punching && p1_facing_p2;
//     // assign p2_hit_p1 = touching && p2_punching && p2_facing_p1;

// endmodule

module collision_unit(
   input wire [9:0] p1_x, p1_y,          // Top-Left corner of P1's Sprite Domain (64x53)
   input wire [9:0] p2_x, p2_y,          // Top-Left corner of P2's Sprite Domain (64x53)
   input wire p1_punching, p2_punching,  // Is the attack active?
   input wire p1_dir, p2_dir, // Which way are they looking?
   input wire p1_is_jumping, p2_is_jumping,     // ADDED: Are they in the air?
  
   // Unified Hit Outputs
   output wire p1_hit_p2,
   output wire p2_hit_p1 
);


   // ========================================================================
   // 1. SPRITE & HURTBOX DEFINITIONS
   // ========================================================================
   // Sprite Domain Size
   localparam SPRITE_W = 10'd64;
   localparam SPRITE_H = 10'd53;


   // P1 Hurtbox
   localparam P1_HURTBOX_W = 10'd25;
   localparam P1_HURTBOX_H = 10'd38;
   // Calculate centering offsets for P1
   localparam P1_OFFSET_X = (SPRITE_W - P1_HURTBOX_W) / 2; // 19 pixels from left
   localparam P1_OFFSET_Y = (SPRITE_H - P1_HURTBOX_H) / 2; // 7 pixels from top


   // P2 Hurtbox
   localparam P2_HURTBOX_W = 10'd22;
   localparam P2_HURTBOX_H = 10'd33;
   // Calculate centering offsets for P2
   localparam P2_OFFSET_X = (SPRITE_W - P2_HURTBOX_W) / 2; // 21 pixels from left
   localparam P2_OFFSET_Y = (SPRITE_H - P2_HURTBOX_H) / 2; // 10 pixels from top


   // ========================================================================
   // 2. HITBOX DEFINITIONS (Ground vs Jump)
   // ========================================================================
   // P1 Hitboxes
   localparam P1_HITBOX_W  = 10'd19;
   localparam P1_HITBOX_H  = 10'd9;
   localparam P1_HITBOX_Y_OFFSET = 10'd17;


   localparam P1_HITBOX_W_JUMP  = 10'd12;
   localparam P1_HITBOX_H_JUMP  = 10'd10;
   localparam P1_HITBOX_Y_OFFSET_JUMP = 10'd34;


   // P2 Hitboxes
   localparam P2_HITBOX_W  = 10'd14;
   localparam P2_HITBOX_H  = 10'd8;
   localparam P2_HITBOX_Y_OFFSET = 10'd22;


   localparam P2_HITBOX_W_JUMP  = 10'd13;
   localparam P2_HITBOX_H_JUMP  = 10'd10;
   localparam P2_HITBOX_Y_OFFSET_JUMP = 10'd34;


   // ========================================================================
   // 3. CALCULATE EXACT HURTBOX COORDINATES
   // ========================================================================
   // Center the hurtboxes inside the sprite domain based on the calculated offsets
   wire [9:0] p1_hurtbox_left   = p1_x + P1_OFFSET_X;
   wire [9:0] p1_hurtbox_right  = p1_hurtbox_left + P1_HURTBOX_W;
   wire [9:0] p1_hurtbox_top    = p1_y + P1_OFFSET_Y;
   wire [9:0] p1_hurtbox_bottom = p1_hurtbox_top + P1_HURTBOX_H;


   wire [9:0] p2_hurtbox_left   = p2_x + P2_OFFSET_X;
   wire [9:0] p2_hurtbox_right  = p2_hurtbox_left + P2_HURTBOX_W;
   wire [9:0] p2_hurtbox_top    = p2_y + P2_OFFSET_Y;
   wire [9:0] p2_hurtbox_bottom = p2_hurtbox_top + P2_HURTBOX_H;


   // ========================================================================
   // 4. DYNAMIC HITBOX MULTIPLEXING
   // ========================================================================
   // Select width, height, and Y-offset based on whether the player is jumping
   wire [9:0] p1_current_hitbox_w = p1_is_jumping ? P1_HITBOX_W_JUMP : P1_HITBOX_W;
   wire [9:0] p1_current_hitbox_h = p1_is_jumping ? P1_HITBOX_H_JUMP : P1_HITBOX_H;
   wire [9:0] p1_current_y_offset = p1_is_jumping ? P1_HITBOX_Y_OFFSET_JUMP : P1_HITBOX_Y_OFFSET;


   wire [9:0] p2_current_hitbox_w = p2_is_jumping ? P2_HITBOX_W_JUMP : P2_HITBOX_W;
   wire [9:0] p2_current_hitbox_h = p2_is_jumping ? P2_HITBOX_H_JUMP : P2_HITBOX_H;
   wire [9:0] p2_current_y_offset = p2_is_jumping ? P2_HITBOX_Y_OFFSET_JUMP : P2_HITBOX_Y_OFFSET;


   // ========================================================================
   // 5. CALCULATE EXACT HITBOX COORDINATES
   // ========================================================================
   // --- P1 HITBOX ---
   // Spawns immediately off the left or right edge of the *Hurtbox*, not the sprite edge!
   wire [9:0] p1_hitbox_left = p1_dir ? p1_hurtbox_right :
                               ((p1_hurtbox_left > p1_current_hitbox_w) ? (p1_hurtbox_left - p1_current_hitbox_w) : 10'd0);
   wire [9:0] p1_hitbox_right = p1_hitbox_left + p1_current_hitbox_w;
   wire [9:0] p1_hitbox_top = p1_y + p1_current_y_offset;
   wire [9:0] p1_hitbox_bottom = p1_hitbox_top + p1_current_hitbox_h;


   // --- P2 HITBOX ---
   wire [9:0] p2_hitbox_left = p2_dir ? p2_hurtbox_right :
                               ((p2_hurtbox_left > p2_current_hitbox_w) ? (p2_hurtbox_left - p2_current_hitbox_w) : 10'd0);
   wire [9:0] p2_hitbox_right = p2_hitbox_left + p2_current_hitbox_w;
   wire [9:0] p2_hitbox_top = p2_y + p2_current_y_offset;
   wire [9:0] p2_hitbox_bottom = p2_hitbox_top + p2_current_hitbox_h;


   // ========================================================================
   // 6. COLLISION DETECTION (Hitbox vs Hurtbox)
   // ========================================================================
   // --- P1 Attacking P2 ---
   wire p1_punch_hits_x = (p1_hitbox_left < p2_hurtbox_right) && (p1_hitbox_right > p2_hurtbox_left);
   wire p1_punch_hits_y = (p1_hitbox_top < p2_hurtbox_bottom) && (p1_hitbox_bottom > p2_hurtbox_top);
  
   assign p1_hit_p2 = p1_punching && p1_punch_hits_x && p1_punch_hits_y;


   // --- P2 Attacking P1 ---
   wire p2_punch_hits_x = (p2_hitbox_left < p1_hurtbox_right) && (p2_hitbox_right > p1_hurtbox_left);
   wire p2_punch_hits_y = (p2_hitbox_top < p1_hurtbox_bottom) && (p2_hitbox_bottom > p1_hurtbox_top);
  
   assign p2_hit_p1 = p2_punching && p2_punch_hits_x && p2_punch_hits_y;


endmodule