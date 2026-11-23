// -----------------------------------------------------------------------------
// Module : lcd1602_test_tb
// Purpose: Self-checking testbench with a behavioral HD44780 model (4-bit,
//          write-only). Prints "RESULT: PASS" or "RESULT: FAIL".
// -----------------------------------------------------------------------------
`timescale 1ns/1ps
module lcd1602_test_tb;
    reg        clk = 1'b0;
    reg  [3:0] btn = 4'd0;
    reg  [1:0] sw  = 2'd0;
    wire [3:0] led;
    wire       rs;
    wire       e;
    wire [3:0] d;
    integer    errors = 0;

    always #4 clk = ~clk;   // 125 MHz

    lcd1602_test_top #(
        .PWR_CYC  (2000),
        .INIT_CYC (6250),      // 50 us
        .WAIT_CYC (6250),      // 50 us (> 37 us HD44780 execution time)
        .PHASE_CYC(1250),      // real value: 10 us
        .SEC_CYC  (2500000)    // 20 ms "second"
    ) dut (
        .sysclk_i(clk), .btn_i(btn), .sw_i(sw), .led_o(led),
        .lcd_rs_o(rs), .lcd_e_o(e), .lcd_d_o(d)
    );

    // ---------------- HD44780 model ----------------
    reg        mode8    = 1'b1;
    reg        have_hi  = 1'b0;
    reg  [3:0] hi       = 4'd0;
    reg  [7:0] ddram [0:127];
    reg  [7:0] cgram [0:63];
    reg  [6:0] addr     = 7'd0;
    reg        in_cgram = 1'b0;
    reg        seen_28  = 1'b0;
    reg        seen_0c  = 1'b0;
    reg        seen_01  = 1'b0;
    reg        seen_06  = 1'b0;
    integer    n_init3  = 0;
    integer    k;
    realtime   t_rise        = 0;
    realtime   t_data_change = 0;

    initial for (k = 0; k < 128; k = k + 1) ddram[k] = 8'h20;
    initial for (k = 0; k < 64;  k = k + 1) cgram[k] = 8'h00;

    always @(d or rs) t_data_change = $realtime;

    always @(posedge e) begin
        t_rise = $realtime;
        if ($realtime - t_data_change < 60) begin   // address/data setup
            errors = errors + 1;
            $display("FAIL setup time at %t", $realtime);
        end
    end

    task exec;
        input       is_data;
        input [7:0] b;
        begin
            if (is_data) begin
                if (in_cgram) cgram[addr[5:0]] = b;
                else          ddram[addr]      = b;
                addr = addr + 7'd1;
            end else begin
                if (b == 8'h28) seen_28 = 1'b1;
                if (b == 8'h0C) seen_0c = 1'b1;
                if (b == 8'h06) seen_06 = 1'b1;
                if (b == 8'h01) begin
                    seen_01 = 1'b1;
                    for (k = 0; k < 128; k = k + 1) ddram[k] = 8'h20;
                    addr     = 7'd0;
                    in_cgram = 1'b0;
                end
                if (b[7]) begin
                    addr     = b[6:0];
                    in_cgram = 1'b0;
                end else if (b[7:6] == 2'b01) begin
                    addr     = {1'b0, b[5:0]};
                    in_cgram = 1'b1;
                end
            end
        end
    endtask

    always @(negedge e) if ($realtime > 0) begin   // skip the time-0 X->0 event
        if ($realtime - t_rise < 450) begin
            errors = errors + 1;
            $display("FAIL E pulse too short at %t", $realtime);
        end
        if (mode8) begin
            if (d == 4'h3)      n_init3 = n_init3 + 1;
            else if (d == 4'h2) mode8 = 1'b0;
            else begin
                errors = errors + 1;
                $display("FAIL bad init nibble %h", d);
            end
        end else if (!have_hi) begin
            hi      = d;
            have_hi = 1'b1;
        end else begin
            have_hi = 1'b0;
            exec(rs, {hi, d});
        end
    end

    // ---------------- checks ----------------
    task check_line;
        input [6:0]   base;
        input [127:0] exp;
        integer c;
        begin
            for (c = 0; c < 16; c = c + 1)
                if (ddram[base + c] !== exp[8*(15-c) +: 8]) begin
                    errors = errors + 1;
                    $display("FAIL ddram[%h] = %h, expected %h",
                             base + c, ddram[base + c], exp[8*(15-c) +: 8]);
                end
        end
    endtask

    initial begin
        wait (led[0] == 1'b1);          // first full draw finished
        #1000;
        if (n_init3 != 3) begin
            errors = errors + 1;
            $display("FAIL init 3s = %0d", n_init3);
        end
        if (mode8) begin
            errors = errors + 1;
            $display("FAIL never entered 4-bit mode");
        end
        if (!(seen_28 && seen_0c && seen_01 && seen_06)) begin
            errors = errors + 1;
            $display("FAIL missing init command");
        end
        if (cgram[1] !== 8'h0A || cgram[2] !== 8'h1F || cgram[6] !== 8'h04 ||
            cgram[12] !== 8'h11 || cgram[13] !== 8'h0E) begin
            errors = errors + 1;
            $display("FAIL cgram content");
        end
        check_line(7'h00, "PYNQ-Z2 + 1602A ");
        check_line(7'h40, {8'h00, " OK ", 8'h01, "  T=0000s "});

        #45000000;                      // 2 fake seconds have elapsed
        check_line(7'h40, {8'h00, " OK ", 8'h01, "  T=0002s "});

        sw = 2'b01;                     // page 1
        #20000000;                      // 3 fake seconds elapsed: countdown = 7
        check_line(7'h00, {"Are you OK?   ", 8'h00, 8'h01});
        check_line(7'h40, "Cancel in:  7 s ");

        btn = 4'b0001;                  // restart
        #100000;
        btn = 4'b0000;
        #1000;
        if (led[0] !== 1'b0) begin
            errors = errors + 1;
            $display("FAIL restart did not clear init_done");
        end
        mode8   = 1'b1;
        have_hi = 1'b0;
        n_init3 = 0;
        wait (led[0] == 1'b1);
        #1000;
        check_line(7'h40, "Cancel in: 10 s ");

        if (errors == 0) $display("RESULT: PASS");
        else             $display("RESULT: FAIL (%0d errors)", errors);
        $finish;
    end

    initial begin
        #400000000;
        $display("RESULT: FAIL (timeout)");
        $finish;
    end
endmodule
