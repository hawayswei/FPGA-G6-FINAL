// ============================================================================
// Module : ctrl_button
// Owner  : integrator
// Purpose: Debounce one push button and tell short presses from long presses.
//            short_o : one-cycle pulse when the button is released before
//                      LONG_CYCLES
//            long_o  : one-cycle pulse when the button has been held for
//                      LONG_CYCLES (no short pulse follows on release)
//            held_o  : debounced level, 1 = pressed
// Clock  : clk_i (125 MHz system clock).
// Reset  : rst_n_i, synchronous, active low.
// ============================================================================
`timescale 1ns / 1ps

module ctrl_button #(
    parameter DEBOUNCE_CYCLES = 2500000,     // 20 ms
    parameter LONG_CYCLES     = 250000000    // 2 s
) (
    input  wire clk_i,
    input  wire rst_n_i,
    input  wire btn_i,           // raw button, 1 = pressed (asynchronous)
    output reg  short_o = 1'b0,
    output reg  long_o  = 1'b0,
    output reg  held_o  = 1'b0
);

    reg [1:0]  sync_r     = 2'b00;
    reg [31:0] db_cnt_r   = 32'd0;
    reg [31:0] hold_cnt_r = 32'd0;
    reg        long_done_r = 1'b0;

    always @(posedge clk_i) begin
        sync_r <= {sync_r[0], btn_i};
    end

    always @(posedge clk_i) begin
        if (!rst_n_i) begin
            short_o     <= 1'b0;
            long_o      <= 1'b0;
            held_o      <= 1'b0;
            db_cnt_r    <= 32'd0;
            hold_cnt_r  <= 32'd0;
            long_done_r <= 1'b0;
        end else begin
            short_o <= 1'b0;
            long_o  <= 1'b0;

            // debounce: the level must differ from held_o for DEBOUNCE_CYCLES in a row
            if (sync_r[1] == held_o) begin
                db_cnt_r <= 32'd0;
            end else if (db_cnt_r == DEBOUNCE_CYCLES - 1) begin
                db_cnt_r <= 32'd0;
                held_o   <= sync_r[1];
                if (held_o && !long_done_r) short_o <= 1'b1;   // released early
                if (held_o)                 long_done_r <= 1'b0;
                if (!held_o)                hold_cnt_r  <= 32'd0;
            end else begin
                db_cnt_r <= db_cnt_r + 32'd1;
            end

            // long press
            if (held_o && !long_done_r) begin
                if (hold_cnt_r == LONG_CYCLES - 1) begin
                    long_o      <= 1'b1;
                    long_done_r <= 1'b1;
                end else begin
                    hold_cnt_r <= hold_cnt_r + 32'd1;
                end
            end
        end
    end

endmodule
