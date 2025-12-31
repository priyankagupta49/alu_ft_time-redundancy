`timescale 1ns / 1ps

module tb_alu_time_redundancy;

    reg clk;
    reg rst;

    always #5 clk = ~clk;

    reg [31:0] A, B;
    reg [2:0]  ALUControl;

    wire [31:0] alu_res_ft;
    wire        fault_detected;

    // DUT
    ALU_ft dut (
        .clk(clk),
        .rst(rst),
        .A(A),
        .B(B),
        .ALUControl(ALUControl),
        .Result(alu_res_ft),
        .Zero(),
        .Carry(),
        .OverFlow(),
        .Negative(),
        .fault_detected_out(fault_detected)
    );

    // Stage monitors
    reg [31:0] stage1_res, stage2_res, stage3_res;

    initial begin
        clk = 0;
        rst = 0;
        A = 0;
        B = 0;
        ALUControl = 0;

        $display("3-STAGE TIME REDUNDANCY");
     

        #12 rst = 1;

        // Constant inputs
        A = 32'hF5;
        B = 32'haa;
        ALUControl = 3'b010; // ADD 

        // ---------------- STAGE-1 ----------------
@(posedge clk);
//#2 force dut.u_alu.Result = ~dut.u_alu.Result;
#1 stage1_res = dut.res_t1;
$display("Stage-1 Result = %0d", stage1_res);

// ---------------- STAGE-2 ----------------
@(posedge clk);
   #2 force dut.u_alu.Result = ~dut.u_alu.Result;
#1 stage2_res = dut.u_alu.Result;
$display("Stage-2 Result = %0d", stage2_res);

// ---------------- DECISION BEFORE STAGE-3 ----------------
if (stage1_res != stage2_res) begin
    $display("Mismatch detected : Stage-3 enabled");

   

    // ---------------- STAGE-3 ----------------
    @(posedge clk);
    #1 stage3_res = alu_res_ft;
    release dut.u_alu.Result;

    $display("Stage-3 Result = %0d", stage3_res);

    if (fault_detected)
        $display("PASS: Fault detected ");

    if (stage3_res == stage1_res)
        $display("PASS: Final output correct = %0d", stage3_res);
    else
        $display("FAIL: Final output incorrect");

end
else begin
    $display("No mismatch ");

    if (!fault_detected)
        $display("PASS: No fault");

//    if (alu_res_ft == stage1_res)
//        $display("PASS: Final output correct = %0d", alu_res_ft);
//    else
//        $display("FAIL: Final output incorrect");
end
 


//        // ---------------- CHECK ----------------
//        if (stage1_res != stage2_res) begin
//            if (fault_detected)
//                $display("PASS: Fault detected ");
//            else
//                $display("FAIL: Fault NOT detected");
//        end
//        else begin
//            if (!fault_detected)
//                $display("PASS: No fault ");
//            else
//                $display("FAIL: False fault detected");
//        end

      



        #20 $finish;
    end

endmodule
