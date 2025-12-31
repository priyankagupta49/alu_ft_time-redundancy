`timescale 1ns / 1ps

module execute_cycle(
    input clk, rst,
    input RegWriteE, ALUSrcE, MemWriteE, ResultSrcE, BranchE,
    input [2:0] ALUControlE,
    input [38:0] RD1_E_ECC, RD2_E_ECC, Imm_Ext_E_ECC, PCE_ECC, PCPlus4E_ECC,
    input [4:0] RD_E,
    input [31:0] ResultW,
    input [1:0] ForwardA_E, ForwardB_E,
    input [31:0] ALU_ResultM_In, 
    input test_en_in,
    output PCSrcE, RegWriteM, MemWriteM, ResultSrcM,
    output [4:0] RD_M,
    output [38:0] ALU_ResultM_ECC, WriteDataM_ECC, PCPlus4M_ECC,
    output [31:0] PCTargetE,
    output hardware_fault_flag 
);

    // --- Internal Wires ---
    wire [31:0] RD1_E, RD2_E, Imm_Ext_E, PCE, PCPlus4E;
    wire [31:0] Src_A, Src_B_interim, Src_B;
    wire [31:0] Final_ResultE;
    wire Final_ZeroE;
    wire alu_fault;

    // -------------------------------------------------------------------------
    // 1. ECC DECODING: Correct faults from the ID/EX Pipeline Registers
    // -------------------------------------------------------------------------
    hamming_ecc_unit dec_rd1 (.data_in(32'b0), .code_in(RD1_E_ECC),     .data_out(RD1_E));
    hamming_ecc_unit dec_rd2 (.data_in(32'b0), .code_in(RD2_E_ECC),     .data_out(RD2_E));
    hamming_ecc_unit dec_imm (.data_in(32'b0), .code_in(Imm_Ext_E_ECC), .data_out(Imm_Ext_E));
    hamming_ecc_unit dec_pce (.data_in(32'b0), .code_in(PCE_ECC),       .data_out(PCE));
    hamming_ecc_unit dec_pc4 (.data_in(32'b0), .code_in(PCPlus4E_ECC),  .data_out(PCPlus4E));

    // -------------------------------------------------------------------------
    // 2. OPERAND SELECTION (Forwarding & Muxes)
    // -------------------------------------------------------------------------
    // Note: Mux_3_by_1 still maintains its internal BIST/Spare logic
    Mux_3_by_1 srca_mux (
        .clk(clk), .rst(rst), .test_en(test_en_in),
        .a(RD1_E), .b(ResultW), .c(ALU_ResultM_In), 
        .s(ForwardA_E), .d(Src_A), 
        .mux_fault_sticky() // Connect to top mux error flag if needed
    );

    Mux_3_by_1 srcb_mux (
        .clk(clk), .rst(rst), .test_en(test_en_in),
        .a(RD2_E), .b(ResultW), .c(ALU_ResultM_In), 
        .s(ForwardB_E), .d(Src_B_interim), 
        .mux_fault_sticky()
    );

    Mux alu_src_mux (.a(Src_B_interim), .b(Imm_Ext_E), .s(ALUSrcE), .c(Src_B));

    // This replaces the Primary/Spare separate instantiation and the BIST MISR
    ALU_ft ft_alu_unit (
        .clk(clk), 
        .rst(rst),
        .A(Src_A), 
        .B(Src_B),
        .ALUControl(ALUControlE),
        .Result(Final_ResultE),
        .Zero(Final_ZeroE),
        .Carry(),    // Connect if status flags are needed in pipeline
        .OverFlow(), 
        .Negative(),
        .fault_detected_out(alu_fault)
    );

    // Hardware fault flag is now driven by the Time Redundancy mismatch
    assign hardware_fault_flag = alu_fault;

    
    wire [38:0] alu_enc, wd_enc, pc4_enc;
    hamming_ecc_unit enc_alu (.data_in(Final_ResultE), .code_in(39'b0), .code_out(alu_enc));
    hamming_ecc_unit enc_wd  (.data_in(Src_B_interim), .code_in(39'b0), .code_out(wd_enc));
    hamming_ecc_unit enc_pc4 (.data_in(PCPlus4E),      .code_in(39'b0), .code_out(pc4_enc));

    
    reg RegWriteM_r, MemWriteM_r, ResultSrcM_r;
    reg [4:0] RD_M_r;
    reg [38:0] ALU_ResultM_r, WriteDataM_r, PCPlus4M_r;

    always @(posedge clk or negedge rst) begin
        if (rst == 1'b0) begin
            RegWriteM_r   <= 1'b0; MemWriteM_r <= 1'b0; ResultSrcM_r <= 1'b0;
            RD_M_r        <= 5'b0; 
            ALU_ResultM_r <= 39'b0; 
            WriteDataM_r  <= 39'b0; 
            PCPlus4M_r    <= 39'b0;
        end else begin
            RegWriteM_r   <= RegWriteE; 
            MemWriteM_r   <= MemWriteE; 
            ResultSrcM_r  <= ResultSrcE;
            RD_M_r        <= RD_E; 
            ALU_ResultM_r <= alu_enc; 
            WriteDataM_r  <= wd_enc; 
            PCPlus4M_r    <= pc4_enc; 
        end
    end

    
    PC_Adder branch_adder (.a(PCE), .b(Imm_Ext_E), .c(PCTargetE));
    assign PCSrcE = Final_ZeroE & BranchE;

    assign RegWriteM      = RegWriteM_r; 
    assign MemWriteM      = MemWriteM_r; 
    assign ResultSrcM     = ResultSrcM_r;
    assign RD_M           = RD_M_r; 
    assign ALU_ResultM_ECC = ALU_ResultM_r;
    assign WriteDataM_ECC = WriteDataM_r; 
    assign PCPlus4M_ECC   = PCPlus4M_r;

endmodule