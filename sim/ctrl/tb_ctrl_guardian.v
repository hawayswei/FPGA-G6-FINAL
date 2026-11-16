// ============================================================================
// Testbench : tb_ctrl_guardian
// DUT       : ctrl_button + ctrl_guardian_fsm with shortened timing
//             (1 "second" = 20 clocks, debounce 4 clocks, long press 60 clocks)
// Checks    : 1. button glitches are ignored
//             2. fall -> ASK -> short press cancels (ev_ok)
//             3. fall -> ASK -> 10 s timeout -> ALARM (ev_fall), repeat after
//                5 s, short press clears (ev_ok)
//             4. long press -> ALARM as SOS (ev_sos), releasing the button
//                does not clear it, short press clears
//             5. long press during ASK -> SOS
// Run time  : finishes by itself in under 40 us.
// Expected  : prints "TB PASS".
// ============================================================================
`timescale 1ns / 1ps

module tb_ctrl_guardian;

    localparam SEC = 20;             // clocks per "second"

    reg  clk_i = 1'b0, rst_n_i = 1'b0, btn = 1'b0, fall = 1'b0;
    wire btn_short, btn_long, btn_held;
    wire [1:0] state;
    wire [7:0] ask_left;
    wire alarm_sos, ev_ask, ev_fall, ev_sos, ev_ok;

    integer errors = 0;
    integer n_ask = 0, n_fall = 0, n_sos = 0, n_ok = 0;
    integer t_ask = 0, t_alarm = 0, cyc = 0;

    ctrl_button #(.DEBOUNCE_CYCLES(4), .LONG_CYCLES(60)) u_btn (
        .clk_i (clk_i), .rst_n_i (rst_n_i), .btn_i (btn),
        .short_o (btn_short), .long_o (btn_long), .held_o (btn_held)
    );

    ctrl_guardian_fsm #(.CYCLES_PER_SECOND(SEC), .ASK_SECONDS(10), .REPEAT_SECONDS(5)) dut (
        .clk_i (clk_i), .rst_n_i (rst_n_i),
        .fall_i (fall), .btn_short_i (btn_short), .btn_long_i (btn_long),
        .state_o (state), .ask_left_o (ask_left), .alarm_sos_o (alarm_sos),
        .ev_ask_o (ev_ask), .ev_fall_o (ev_fall), .ev_sos_o (ev_sos), .ev_ok_o (ev_ok)
    );

    always #4 clk_i = ~clk_i;

    always @(posedge clk_i) begin
        cyc = cyc + 1;
        if (ev_ask)  begin n_ask  = n_ask  + 1; t_ask = cyc; end
        if (ev_fall) begin n_fall = n_fall + 1; if (t_alarm < t_ask) t_alarm = cyc; end
        if (ev_sos)  n_sos = n_sos + 1;
        if (ev_ok)   n_ok  = n_ok  + 1;
    end

    task expect_state;
        input [1:0] s;
        input [8*24-1:0] what;
        begin
            if (state !== s) begin
                errors = errors + 1;
                $display("TB ERROR: %0s: state=%0d expected %0d", what, state, s);
            end
        end
    endtask

    task expect_counts;
        input integer a, f, s, o;
        input [8*24-1:0] what;
        begin
            if (n_ask != a || n_fall != f || n_sos != s || n_ok != o) begin
                errors = errors + 1;
                $display("TB ERROR: %0s: ask/fall/sos/ok = %0d/%0d/%0d/%0d expected %0d/%0d/%0d/%0d",
                         what, n_ask, n_fall, n_sos, n_ok, a, f, s, o);
            end
        end
    endtask

    task press;
        input integer cycles;
        begin
            btn = 1'b1; repeat (cycles) @(posedge clk_i);
            btn = 1'b0; repeat (12) @(posedge clk_i);
        end
    endtask

    task do_fall;
        begin
            @(posedge clk_i); fall <= 1'b1;
            @(posedge clk_i); fall <= 1'b0;
            repeat (3) @(posedge clk_i);
        end
    endtask

    initial begin
        #40 rst_n_i = 1'b1;
        repeat (5) @(posedge clk_i);

        // 1. glitches shorter than the debounce time
        repeat (3) begin btn = 1'b1; repeat (2) @(posedge clk_i); btn = 1'b0; repeat (3) @(posedge clk_i); end
        repeat (10) @(posedge clk_i);
        expect_state(2'd0, "glitch");
        expect_counts(0, 0, 0, 0, "glitch");

        // a short press while monitoring does nothing
        press(20);
        expect_state(2'd0, "short press in MONITOR");

        // 2. fall, cancelled
        do_fall;
        expect_state(2'd1, "fall -> ASK");
        if (ask_left !== 8'd10) begin errors = errors + 1; $display("TB ERROR: ask_left=%0d", ask_left); end
        repeat (3 * SEC) @(posedge clk_i);
        press(20);
        expect_state(2'd0, "cancel");
        expect_counts(1, 0, 0, 1, "cancel");

        // 3. fall, timeout, repeat, clear
        do_fall;
        repeat (10 * SEC + 5) @(posedge clk_i);
        expect_state(2'd2, "timeout -> ALARM");
        expect_counts(2, 1, 0, 1, "timeout");
        if (t_alarm - t_ask != 10 * SEC) begin
            errors = errors + 1;
            $display("TB ERROR: ASK lasted %0d clocks, expected %0d", t_alarm - t_ask, 10 * SEC);
        end
        if (alarm_sos !== 1'b0) begin errors = errors + 1; $display("TB ERROR: alarm_sos set for a fall"); end
        repeat (5 * SEC) @(posedge clk_i);
        expect_counts(2, 2, 0, 1, "repeat");
        press(20);
        expect_state(2'd0, "clear");
        expect_counts(2, 2, 0, 2, "clear");

        // 4. manual SOS
        btn = 1'b1; repeat (80) @(posedge clk_i);
        expect_state(2'd2, "long press -> ALARM");
        btn = 1'b0; repeat (12) @(posedge clk_i);
        expect_state(2'd2, "release keeps ALARM");
        expect_counts(2, 2, 1, 2, "sos");
        if (alarm_sos !== 1'b1) begin errors = errors + 1; $display("TB ERROR: alarm_sos not set"); end
        press(20);
        expect_state(2'd0, "clear sos");
        expect_counts(2, 2, 1, 3, "clear sos");

        // 5. long press during ASK
        do_fall;
        press(80);
        expect_state(2'd2, "long press in ASK");
        expect_counts(3, 2, 2, 3, "sos from ASK");
        press(20);
        expect_state(2'd0, "final clear");

        if (errors == 0) $display("TB PASS: button and system FSM behave as specified");
        else             $display("TB FAIL: %0d errors", errors);
        $finish;
    end

    initial begin
        #400000;
        $display("TB FAIL: timeout");
        $finish;
    end

endmodule
