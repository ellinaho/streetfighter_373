module collision_unit(
   //from vga
   input wire [9:0] p1_x, p1_y,       
   input wire [9:0] p2_x, p2_y,        

   //from player game state 
   input wire [3:0] p1_state,
   input wire [3:0] p2_state,
   input wire p1_dir, p2_dir, // Which way are they looking?
  
   //output to player controller
   output wire p1_hit_p2,
   output wire p2_hit_p1 
);

   parameter JUMP = 3, PUNCH = 2;
   
   wire p1_jumping = (p1_state == JUMP);
   wire p1_punching = (p1_state == PUNCH);
   wire p2_jumping = (p2_state == JUMP);
   wire p2_punching = (p2_state == PUNCH);

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
   wire [9:0] p1_current_hitbox_w = p1_jumping ? P1_HITBOX_W_JUMP : P1_HITBOX_W;
   wire [9:0] p1_current_hitbox_h = p1_jumping ? P1_HITBOX_H_JUMP : P1_HITBOX_H;
   wire [9:0] p1_current_y_offset = p1_jumping ? P1_HITBOX_Y_OFFSET_JUMP : P1_HITBOX_Y_OFFSET;


   wire [9:0] p2_current_hitbox_w = p2_jumping ? P2_HITBOX_W_JUMP : P2_HITBOX_W;
   wire [9:0] p2_current_hitbox_h = p2_jumping ? P2_HITBOX_H_JUMP : P2_HITBOX_H;
   wire [9:0] p2_current_y_offset = p2_jumping ? P2_HITBOX_Y_OFFSET_JUMP : P2_HITBOX_Y_OFFSET;


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