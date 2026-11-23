// ============================================================================
// Module : ctrl_guardian_fsm
// Owner  : integrator
// Purpose: System state machine of the Invisible Guardian.
//            MONITOR : normal. fall_i -> ASK. Long press -> ALARM (manual SOS).
//            ASK     : "Are you OK?" for ASK_SECONDS. Short press -> MONITOR
//                      (cancelled). Long press -> ALARM (SOS). Timeout ->
//                      ALARM (fall).
//            ALARM   : latched until a short press. The alert event is
//                      repeated every REPEAT_SECONDS.
//          Events are one-cycle pulses for the Bluetooth message sender:
//            ev_fall_o, ev_sos_o (also the repeats), ev_ok_o (cancel / clear),
//            ev_ask_o (entered ASK).
// Clock  : clk_i (125 MHz system clock).
// Reset  : rst_n_i, synchronous, active low.
// ============================================================================
`timescale 1ns / 1ps

module ctrl_guardian_fsm #(
    parameter CYCLES_PER_SECOND = 125000000,
    parameter ASK_SECONDS       = 10,
    parameter REPEAT_SECONDS    = 5
) (
    input  wire       clk_i,
    input  wire       rst_n_i,
    input  wire       fall_i,          // one-cycle pulse from fall_detect
    input  wire       btn_short_i,
    input  wire       btn_long_i,
    output reg  [1:0] state_o      = 2'd0,
    output reg  [7:0] ask_left_o   = 8'd0,   // seconds left in ASK (for the display)
    output reg        alarm_sos_o  = 1'b0,   // in ALARM: 1 = manual SOS, 0 = fall
    output reg        ev_ask_o     = 1'b0,
    output reg        ev_fall_o    = 1'b0,
    output reg        ev_sos_o     = 1'b0,
    output reg        ev_ok_o      = 1'b0
);

    localparam [1:0] ST_MONITOR = 2'd0;
    localparam [1:0] ST_ASK     = 2'd1;
    localparam [1:0] ST_ALARM   = 2'd2;

    reg [31:0] sec_cnt_r    = 32'd0;
    reg [7:0]  repeat_cnt_r = 8'd0;

    wire sec_tick = (sec_cnt_r == CYCLES_PER_SECOND - 1);

    always @(posedge clk_i) begin
        if (!rst_n_i) begin
            state_o      <= ST_MONITOR;
            ask_left_o   <= 8'd0;
            alarm_sos_o  <= 1'b0;
            ev_ask_o     <= 1'b0;
            ev_fall_o    <= 1'b0;
            ev_sos_o     <= 1'b0;
            ev_ok_o      <= 1'b0;
            sec_cnt_r    <= 32'd0;
            repeat_cnt_r <= 8'd0;
        end else begin
            ev_ask_o  <= 1'b0;
            ev_fall_o <= 1'b0;
            ev_sos_o  <= 1'b0;
            ev_ok_o   <= 1'b0;
            sec_cnt_r <= sec_tick ? 32'd0 : sec_cnt_r + 32'd1;

            case (state_o)
                ST_MONITOR: begin
                    if (btn_long_i) begin
                        state_o      <= ST_ALARM;
                        alarm_sos_o  <= 1'b1;
                        ev_sos_o     <= 1'b1;
                        sec_cnt_r    <= 32'd0;
                        repeat_cnt_r <= 8'd0;
                    end else if (fall_i) begin
                        state_o    <= ST_ASK;
                        ask_left_o <= ASK_SECONDS;
                        ev_ask_o   <= 1'b1;
                        sec_cnt_r  <= 32'd0;
                    end
                end

                ST_ASK: begin
                    if (btn_short_i) begin
                        state_o    <= ST_MONITOR;
                        ask_left_o <= 8'd0;
                        ev_ok_o    <= 1'b1;
                    end else if (btn_long_i) begin
                        state_o      <= ST_ALARM;
                        alarm_sos_o  <= 1'b1;
                        ev_sos_o     <= 1'b1;
                        ask_left_o   <= 8'd0;
                        sec_cnt_r    <= 32'd0;
                        repeat_cnt_r <= 8'd0;
                    end else if (sec_tick) begin
                        if (ask_left_o <= 8'd1) begin
                            state_o      <= ST_ALARM;
                            alarm_sos_o  <= 1'b0;
                            ev_fall_o    <= 1'b1;
                            ask_left_o   <= 8'd0;
                            repeat_cnt_r <= 8'd0;
                        end else begin
                            ask_left_o <= ask_left_o - 8'd1;
                        end
                    end
                end

                ST_ALARM: begin
                    if (btn_short_i) begin
                        state_o <= ST_MONITOR;
                        ev_ok_o <= 1'b1;
                    end else if (sec_tick) begin
                        if (repeat_cnt_r == REPEAT_SECONDS - 1) begin
                            repeat_cnt_r <= 8'd0;
                            if (alarm_sos_o) ev_sos_o  <= 1'b1;
                            else             ev_fall_o <= 1'b1;
                        end else begin
                            repeat_cnt_r <= repeat_cnt_r + 8'd1;
                        end
                    end
                end

                default: state_o <= ST_MONITOR;
            endcase
        end
    end

endmodule
