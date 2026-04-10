    wire       p1_jump_cmd, p2_jump_cmd;
    wire       p1_punch_cmd, p2_punch_cmd;
    wire [3:0] p1_punch_val, p2_punch_val; // Now it can hold all 4 bits!
    wire       p1_charge_cmd, p2_charge_cmd;
    wire [1:0] p1_move_cmd, p2_move_cmd;   // Now it can hold both bits!

    wire       p1_start_button, p2_start_button;
    wire       rst_button;