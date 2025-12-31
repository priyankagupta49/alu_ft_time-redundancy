`timescale 1ns / 1ps 

module ALU_ft (
    input              clk,
    input              rst,
    input      [31:0]  A,
    input      [31:0]  B,
    input      [2:0]   ALUControl,

    output reg [31:0]  Result,
    output reg         Zero,
    output reg         Carry,
    output reg         OverFlow,
    output reg         Negative,

    output reg         fault_detected_out
);

    
    wire [31:0] alu_res;
    wire alu_z, alu_c, alu_v, alu_n;

    ALU u_alu (
        .A(A),
        .B(B),
        .ALUControl(ALUControl),
        .Result(alu_res),
        .Zero(alu_z),
        .Carry(alu_c),
        .OverFlow(alu_v),
        .Negative(alu_n)
    );

    reg [31:0] res_t1;
    reg        stage3_en;

    // FSM states
    parameter STAGE1 = 2'b00;
    parameter STAGE2 = 2'b01;
    parameter STAGE3 = 2'b10;

    reg [1:0] state;

    // --------------------------------------------------
    // FSM
    // --------------------------------------------------
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            state              <= STAGE1;
            res_t1             <= 32'b0;
            stage3_en          <= 1'b0;
            fault_detected_out <= 1'b0;

            Result   <= 32'b0;
            Zero     <= 1'b0;
            Carry    <= 1'b0;
            OverFlow <= 1'b0;
            Negative <= 1'b0;
        end
        else begin
            case (state)

                // ---------------- STAGE 1 ----------------
                STAGE1: begin
                    res_t1    <= alu_res;   // store first computation
                    stage3_en <= 1'b0;      // clear previous fault
                    state     <= STAGE2;
                end

                // ---------------- STAGE 2 ----------------
                STAGE2: begin
                    if (alu_res == res_t1) begin
                        // No fault → accept result
                        Result   <= alu_res;
                        Zero     <= alu_z;
                        Carry    <= alu_c;
                        OverFlow <= alu_v;
                        Negative <= alu_n;
                        state    <= STAGE1;
                    end
                    else begin
                        // Mismatch → enable stage-3
                        fault_detected_out <= 1'b1;
                        stage3_en <= 1'b1;
                        state <= STAGE3;
                    end
                end

                // ---------------- STAGE 3 ----------------
                STAGE3: begin
                    if (stage3_en) begin
                        // Recovery computation
                        Result   <= alu_res;
                        Zero     <= alu_z;
                        Carry    <= alu_c;
                        OverFlow <= alu_v;
                        Negative <= alu_n;
                    end
                    state <= STAGE1; // return to idle
                end

                default: state <= STAGE1;

            endcase
        end
    end

endmodule
