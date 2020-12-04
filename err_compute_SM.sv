module err_compute_SM(sel, clr_accum, en_accum, err_vld, IR_vld, clk, rst_n);

    output logic [2:0] sel;
    output logic clr_accum;
    output logic en_accum;
    output logic err_vld;
    input logic IR_vld;
    input logic clk, rst_n;

    logic [3:0] real_sel;

    typedef enum logic {IDLE, ACCUM} state_t;
    state_t curr, next;

    // FSM flip-flop
    always_ff @(posedge clk, negedge rst_n) 
        if (!rst_n)
            curr <= IDLE;
        else
            curr <= next;

    always_ff @(posedge clk)
        if (clr_accum)
            real_sel <= 0;
        else if (en_accum)
            real_sel <= real_sel + 1;

    
    // FSM logic 
    always_comb begin
        // default
        clr_accum = 0;
        en_accum = 0;
        err_vld = 0;
        next = IDLE; 
        case (curr)
            IDLE: if (IR_vld) begin
                clr_accum = 1;
                next = ACCUM;
            end else begin
                next = IDLE;
            end
            default: if (real_sel != 4'b1000) begin
                en_accum = 1;
                next = ACCUM;
            end else begin
                err_vld = 1;
                next = IDLE;
            end
        endcase
    end

    assign sel = real_sel[2:0];
    
endmodule
