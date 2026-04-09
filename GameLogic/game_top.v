module game_top(
    input  CLOCK_50,

    //input from vga top 
    input [9:0] p1_x,
    input [9:0] p1_y, 
    input [9:0] p2_x,
    input [9:0] p2_y, 

    //spi inputs
    input p1_jump_cmd, p2_jump_cmd,
    input p1_punch_cmd, p2_punch_cmd,
    input [3:0] p1_punch_val, p2_punch_val,
    input p1_charge_cmd, p2_charge_cmd,
    //input p1_charge, p2_charge,
    input [1:0] p1_move_cmd, p2_move_cmd,

    //driven by player controller
    output [3:0] p1_state,
    output p1_charging,
    output [4:0] p1_charge,
    output [5:0] p1_hp,
    output p1_dir, //1 is facing right?

    output [3:0] p2_state,
    output p2_charging,
    output [4:0] p2_charge,
    output  [5:0] p2_hp,
    output p2_dir,

    //driven by game engine
    output [1:0] game_state,
    output [6:0] time_left,

    //testing? maybe keep
    input p1_start_button,
    input p2_start_button
);

    //driven by collision unit
    wire p1_hit_p2, p2_hit_p1;

    //driven by player controller
    wire p1_fullcharge, p2_fullcharge;
    wire [6:0] p1_damage_val_in, p1_damage_val_out;
    wire [6:0] p2_damage_val_in, p2_damage_val_out;
    assign p1_damage_val_in = p2_damage_val_out;
    assign p2_damage_val_in = p1_damage_val_out;

    //driven by game engine
    wire [1:0] winner;

    collision_unit collision(
       .p1_x(p1_x), 
       .p1_y(p1_y), 
       .p2_x(p2_x), 
       .p2_y(p2_y), //from vga

       .p1_state(p1_state), 
       .p2_state(p2_state),
       .p1_dir(p1_dir), 
       .p2_dir(p2_dir),

       //outputs
       .p1_hit_p2(p1_hit_p2), 
       .p2_hit_p1(p2_hit_p1)
   );

    game_engine game(
        .clk(CLOCK_50), 
        .rst_button(~KEY[0]), 
        .p1_ready(p1_start_button || p1_fullcharge),  //testing
        .p2_ready(p2_start_button || p2_fullcharge),  //testing
        .p1_hp(p1_hp), 
        .p2_hp(p2_hp), 
        .game_state(game_state), 
        .time_left(time_left),
        .winner(winner)
   );

    player_controller p1(
        .clk(CLOCK_50), 
        .game_state(game_state),
        .winner(winner),
        .move_cmd(p1_move_cmd),
        .jump_cmd(p1_jump_cmd), 
        .punch_cmd(p1_punch_cmd), 
        .punch_val(p1_punch_val),
        .charge_cmd(p1_charge_cmd), 
        .getting_hit(p2_hit_p1),
        .damage_val_in(p1_damage_val_in),
        .opponent_x(p2_x), 
        .pos_x(p1_x), 
        .pos_y(p1_y),

        //outputs
        .player_dir(p1_dir), 
        .hp(p1_hp), 
        .is_charging(p1_charging),
        .charge_bar(p1_charge),
        .full_charge(p1_fullcharge),
        .damage_val_out(p1_damage_val_out),
        .player_num(1)
   );

   player_controller p1(
        .clk(CLOCK_50), 
        .game_state(game_state),
        .winner(winner),
        .move_cmd(p2_move_cmd),
        .jump_cmd(p2_jump_cmd), 
        .punch_cmd(p2_punch_cmd), 
        .punch_val(p2_punch_val),
        .charge_cmd(p2_charge_cmd), 
        .getting_hit(p1_hit_p2),
        .damage_val_in(p2_damage_val_in),
        .opponent_x(p1_x), 
        .pos_x(p2_x), 
        .pos_y(p2_y),

        //outputs
        .player_dir(p2_dir), 
        .hp(p2_hp), 
        .is_charging(p2_charging),
        .charge_bar(p2_charge),
        .full_charge(p2_fullcharge),
        .damage_val_out(p2_damage_val_out),
        .player_num(2)
   );



endmodule