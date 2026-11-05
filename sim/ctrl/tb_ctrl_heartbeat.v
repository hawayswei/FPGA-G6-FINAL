// ============================================================================
// Testbench : tb_ctrl_heartbeat
// DUT       : ctrl_heartbeat (WIDTH = 4 so the output toggles quickly)
// Run time  : 2000 ns. In the Vivado MCP/Tcl console use "run 2000ns",
//             never "run all".
// Expected  : prints "TB PASS" when beat_o toggles several times after reset.
// ============================================================================
`timescale 1ns / 1ps

module tb_ctrl_heartbeat;

    reg  clk_i   = 1'b0;
    reg  rst_n_i = 1'b0;
    wire beat_o;

    integer edge_count = 0;

    ctrl_heartbeat #(.WIDTH(4)) dut (
        .clk_i   (clk_i),
        .rst_n_i (rst_n_i),
        .beat_o  (beat_o)
    );

    // 125 MHz clock (8 ns period)
    always #4 clk_i = ~clk_i;

    // Count rising edges of the heartbeat output
    always @(posedge beat_o) edge_count = edge_count + 1;

    initial begin
        #40 rst_n_i = 1'b1;          // release reset after 5 cycles
        #1900;                       // run until about 1940 ns
        if (edge_count >= 5)
            $display("TB PASS: beat_o rose %0d times", edge_count);
        else
            $display("TB FAIL: beat_o rose only %0d times", edge_count);
        $finish;
    end

endmodule
