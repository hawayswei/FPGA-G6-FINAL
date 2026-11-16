// ============================================================================
// Module : ctrl_heartbeat
// Owner  : integrator
// Purpose: Free-running counter whose MSB is a slow "heartbeat" blink.
//          Used as a smoke test that the whole repo flow works
//          (create project -> synthesize -> program board -> LED blinks).
// Clock  : clk_i (125 MHz). Blink period = 2^WIDTH / 125e6 seconds
//          (WIDTH = 27 -> about 1.07 s per full period).
// Reset  : rst_n_i, synchronous, active low.
// ============================================================================
`timescale 1ns / 1ps

module ctrl_heartbeat #(
    parameter WIDTH = 27
) (
    input  wire clk_i,
    input  wire rst_n_i,
    output wire beat_o
);

    reg [WIDTH-1:0] cnt_r;

    always @(posedge clk_i) begin
        if (!rst_n_i)
            cnt_r <= {WIDTH{1'b0}};
        else
            cnt_r <= cnt_r + 1'b1;
    end

    assign beat_o = cnt_r[WIDTH-1];

endmodule
