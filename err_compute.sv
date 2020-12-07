module err_compute(error, err_vld, IR_R0, IR_L0, IR_R1, IR_L1, IR_R2, IR_L2, IR_R3, IR_L3, IR_vld, clk, rst_n);

    output logic [15:0] error;
    output logic err_vld;
    input logic [11:0] IR_R0,IR_R1,IR_R2,IR_R3; // Right IR readings from inside out
    input logic [11:0] IR_L0,IR_L1,IR_L2,IR_L3; // Left IR reading from inside out 
    input logic IR_vld;
    input clk, rst_n;

    // connecting logic
    logic [2:0] sel;
    logic sub;
    logic clr_accum;
    logic en_accum;

    // flop output
    logic [15:0] curr_error;
    logic curr_err_vld;

    assign sub = sel[0]; // sub is equal to sel[0]

    err_compute_SM control(.sel(sel), .clr_accum(clr_accum), .en_accum(en_accum), .err_vld(curr_err_vld), .IR_vld(IR_vld), .clk(clk), .rst_n(rst_n));
    err_compute_DP datapath(.clk(clk), .en_accum(en_accum), .clr_accum(clr_accum), .sub(sub), .sel(sel), .IR_R0(IR_R0), .IR_R1(IR_R1), .IR_R2(IR_R2), .IR_R3(IR_R3), .IR_L0(IR_L0), .IR_L1(IR_L1), .IR_L2(IR_L2), .IR_L3(IR_L3), .error(curr_error));

    // flop the output error
    always_ff @(posedge clk)
        if (curr_err_vld)
            error <= curr_error;

    always_ff @(posedge clk)
        err_vld <= curr_err_vld;

endmodule
