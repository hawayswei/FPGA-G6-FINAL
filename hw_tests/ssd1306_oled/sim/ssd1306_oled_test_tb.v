// -----------------------------------------------------------------------------
// Module : ssd1306_oled_test_tb
// Purpose: Self-checking testbench with a behavioral SSD1306 I2C slave model
//          (write-only, address 0x3C, horizontal addressing, 128x64 GDDRAM).
//          Checks: init command list, open-drain bus (no X), SCL high/low
//          time, START/STOP only on byte boundaries, full 1024-byte frames,
//          text glyphs and border, live counter, checkerboard page, NACK
//          handling (LED2) and recovery, btn0 restart, ignore-NACK
//          switch, RGB line-level / scan indicators, stuck-low SDA.
//          Parameters SWAP = 1 (OLED SCL/SDA wires swapped) and SLAVE_ADDR
//          = 7'h3D run a short test of the diagnostic auto scan instead:
//            xelab ... -generic_top "SWAP=1" -generic_top "SLAVE_ADDR=7'h3D"
//          Prints "RESULT: PASS" or "RESULT: FAIL"; the error counter is
//          also readable as ssd1306_oled_test_tb/errors.
// -----------------------------------------------------------------------------
`timescale 1ns/1ps
module ssd1306_oled_test_tb #(
    parameter       SWAP       = 0,
    parameter [6:0] SLAVE_ADDR = 7'h3C
);
    localparam QTR = 4;

    reg        clk = 1'b0;
    reg  [3:0] btn = 4'd0;
    reg  [1:0] sw  = 2'd0;
    wire [3:0] led;
    wire       scl;        // as seen by the OLED
    wire       sda;
    wire [2:0] rgb4;       // {r, g, b}
    wire [2:0] rgb5;
    integer    errors = 0;
    integer    k;
    integer    p;
    integer    c;

    always #4 clk = ~clk;   // 125 MHz

    pullup (scl);
    pullup (sda);

    // wiring between the FPGA pins (P16 = header SCL, P15 = header SDA) and
    // the OLED pins; SWAP = 1 models the two wires crossed
    generate
        if (SWAP) begin : g_swap
            ssd1306_oled_test_top #(
                .QTR_CYC(QTR), .PWR_CYC(200), .RETRY_CYC(2000), .SEC_CYC(100000)
            ) dut (
                .sysclk_i(clk), .btn_i(btn), .sw_i(sw), .led_o(led),
                .led4_r_o(rgb4[2]), .led4_g_o(rgb4[1]), .led4_b_o(rgb4[0]),
                .led5_r_o(rgb5[2]), .led5_g_o(rgb5[1]), .led5_b_o(rgb5[0]),
                .oled_scl_io(sda), .oled_sda_io(scl)
            );
        end else begin : g_norm
            ssd1306_oled_test_top #(
                .QTR_CYC(QTR), .PWR_CYC(200), .RETRY_CYC(2000),
                .SEC_CYC(100000)    // 0.8 ms "second", about 1.5 per frame
            ) dut (
                .sysclk_i(clk), .btn_i(btn), .sw_i(sw), .led_o(led),
                .led4_r_o(rgb4[2]), .led4_g_o(rgb4[1]), .led4_b_o(rgb4[0]),
                .led5_r_o(rgb5[2]), .led5_g_o(rgb5[1]), .led5_b_o(rgb5[0]),
                .oled_scl_io(scl), .oled_sda_io(sda)
            );
        end
    endgenerate

    // colour of a 1/8-duty RGB LED: OR over 16 clocks
    task rgb_color;
        input         which;     // 0 = LD4, 1 = LD5
        output [2:0]  col_o;
        integer n;
        begin
            col_o = 3'b000;
            for (n = 0; n < 16; n = n + 1) begin
                @(posedge clk);
                col_o = col_o | (which ? rgb5 : rgb4);
            end
        end
    endtask
    reg [2:0] color;

    // ---------------- SSD1306 slave model ----------------
    reg        ack_en   = 1'b1;   // 0 = device absent (never ACKs)
    reg        strict   = 1'b1;   // protocol checks enabled
    reg        sda_drv  = 1'b0;
    assign sda = sda_drv ? 1'b0 : 1'bz;

    reg        in_tr    = 1'b0;
    integer    bitc     = 0;
    reg  [7:0] sh       = 8'h00;
    integer    byte_n   = 0;
    reg        addr_ok  = 1'b0;
    reg        data_mode = 1'b0;
    reg        do_ack;
    integer    cmd_n    = 0;
    reg  [7:0] cmd_log [0:255];
    reg  [7:0] gd [0:1023];
    integer    col_s = 0, col_e = 127, pg_s = 0, pg_e = 7;
    integer    cur_col = 0, cur_pg = 0;
    integer    cs = 0;
    integer    data_in_tr = 0;
    integer    frames     = 0;
    integer    nack_stops = 0;
    realtime   t_rise = 0;
    realtime   t_fall = 0;

    initial for (k = 0; k < 1024; k = k + 1) gd[k] = 8'h55;

    task fail;
        input [8*48-1:0] msg;
        begin
            errors = errors + 1;
            $display("FAIL: %0s at %t", msg, $realtime);
        end
    endtask

    // open-drain: a driven 1 fighting the slave's 0 would give X
    always @(sda or scl)
        if (sda === 1'bx || scl === 1'bx) fail("X on the I2C bus");

    task process_byte;
        input [7:0] b;
        begin
            do_ack = 1'b0;
            if (byte_n == 0) begin
                addr_ok = ack_en && (b == {SLAVE_ADDR, 1'b0});
                do_ack  = addr_ok;
            end else if (!addr_ok) begin
                do_ack = 1'b0;
            end else if (byte_n == 1) begin
                if (b != 8'h00 && b != 8'h40) fail("bad control byte");
                data_mode = (b == 8'h40);
                do_ack    = 1'b1;
            end else if (data_mode) begin
                gd[cur_pg * 128 + cur_col] = b;
                data_in_tr = data_in_tr + 1;
                cur_col = cur_col + 1;
                if (cur_col > col_e) begin
                    cur_col = col_s;
                    cur_pg  = (cur_pg >= pg_e) ? pg_s : cur_pg + 1;
                end
                do_ack = 1'b1;
            end else begin
                cmd_log[cmd_n % 256] = b;
                cmd_n = cmd_n + 1;
                case (cs)
                    0: begin
                        if (b == 8'h21) cs = 1;
                        else if (b == 8'h22) cs = 3;
                        else if (b == 8'h20 || b == 8'h81 || b == 8'h8D ||
                                 b == 8'hA8 || b == 8'hD3 || b == 8'hD5 ||
                                 b == 8'hD9 || b == 8'hDA || b == 8'hDB) cs = 5;
                    end
                    1: begin col_s = b; cs = 2; end
                    2: begin col_e = b; cur_col = col_s; cs = 0; end
                    3: begin pg_s = b; cs = 4; end
                    4: begin pg_e = b; cur_pg = pg_s; cs = 0; end
                    default: cs = 0;
                endcase
                do_ack = 1'b1;
            end
            byte_n = byte_n + 1;
        end
    endtask

    // START: SDA falls while SCL is high
    always @(negedge sda) begin
        if (scl === 1'b1) begin
            if (in_tr && strict) fail("START without STOP");
            in_tr      = 1'b1;
            bitc       = 0;
            byte_n     = 0;
            data_in_tr = 0;
            addr_ok    = 1'b0;
        end
    end

    // STOP: SDA rises while SCL is high
    always @(posedge sda) begin
        if (scl === 1'b1 && in_tr) begin
            // a STOP follows one SCL rise with SDA low, so bitc is 1 here
            if (bitc != 1 && strict) fail("STOP inside a byte");
            if (data_mode && addr_ok && data_in_tr == 1024) frames = frames + 1;
            if (data_mode && addr_ok && data_in_tr != 0 && data_in_tr != 1024 && strict)
                fail("data transfer not 1024 bytes");
            if (!addr_ok && byte_n == 1) nack_stops = nack_stops + 1;
            in_tr = 1'b0;
            data_mode = 1'b0;
        end
    end

    always @(posedge scl) begin
        if (in_tr && strict && ($realtime - t_fall) < 2*QTR*8 - 1)
            fail("SCL low time too short");
        t_rise = $realtime;
        if (in_tr) begin
            if (bitc < 8) sh = {sh[6:0], (sda === 1'b0) ? 1'b0 : 1'b1};
            bitc = bitc + 1;
        end
    end

    always @(negedge scl) begin
        if (in_tr && strict && ($realtime - t_rise) < 2*QTR*8 - 1)
            fail("SCL high time too short");
        t_fall = $realtime;
        if (in_tr) begin
            if (bitc == 8) begin
                process_byte(sh);
                #1 sda_drv = do_ack;            // ACK while SCL is low
            end else if (bitc == 9) begin
                #1 sda_drv = 1'b0;
                bitc = 0;
            end
        end else begin
            sda_drv = 1'b0;
        end
    end

    // ---------------- expected data ----------------
    reg [7:0] exp_init [0:25];
    initial begin
        exp_init[0]  = 8'hAE; exp_init[1]  = 8'hD5; exp_init[2]  = 8'h80;
        exp_init[3]  = 8'hA8; exp_init[4]  = 8'h3F; exp_init[5]  = 8'hD3;
        exp_init[6]  = 8'h00; exp_init[7]  = 8'h40; exp_init[8]  = 8'h8D;
        exp_init[9]  = 8'h14; exp_init[10] = 8'h20; exp_init[11] = 8'h00;
        exp_init[12] = 8'hA1; exp_init[13] = 8'hC8; exp_init[14] = 8'hDA;
        exp_init[15] = 8'h12; exp_init[16] = 8'h81; exp_init[17] = 8'hCF;
        exp_init[18] = 8'hD9; exp_init[19] = 8'hF1; exp_init[20] = 8'hDB;
        exp_init[21] = 8'h40; exp_init[22] = 8'hA4; exp_init[23] = 8'hA6;
        exp_init[24] = 8'h2E; exp_init[25] = 8'hAF;
    end

    task wait_led;
        input integer bit_i;
        input         val;
        input integer max_cyc;
        integer n;
        begin
            n = 0;
            while (led[bit_i] !== val && n < max_cyc) begin
                @(posedge clk);
                n = n + 1;
            end
            if (led[bit_i] !== val) begin
                errors = errors + 1;
                $display("FAIL: timeout waiting for led[%0d]=%0d at %t", bit_i, val, $realtime);
            end
        end
    endtask

    task wait_frames;
        input integer n;
        integer f0;
        integer guard;
        begin
            f0 = frames;
            guard = 0;
            while (frames < f0 + n && guard < 400000 * n) begin
                @(posedge clk);
                guard = guard + 1;
            end
            if (frames < f0 + n) fail("timeout waiting for frames");
        end
    endtask

    task check_byte;
        input integer pg_i;
        input integer col_i;
        input [7:0]   v;
        begin
            if (gd[pg_i * 128 + col_i] !== v) begin
                errors = errors + 1;
                $display("FAIL: GDDRAM page %0d col %0d = %h, expected %h",
                         pg_i, col_i, gd[pg_i * 128 + col_i], v);
            end
        end
    endtask

    reg [7:0] snap [0:23];
    reg [7:0] v0;
    integer   diff;

    initial begin
        if (SWAP || SLAVE_ADDR != 7'h3C) begin
            // diagnostic scan: wrong settings are tried first, ignore the
            // garbage the OLED model sees during those attempts
            strict = 1'b0;
            wait_led(0, 1'b1, 400000);
            rgb_color(1, color);
            if (color !== {SWAP[0], ~SLAVE_ADDR[0], SLAVE_ADDR[0]}) begin
                errors = errors + 1;
                $display("FAIL: LD5 colour %b for SWAP=%0d addr=%h", color, SWAP, SLAVE_ADDR);
            end
            wait_frames(1);
            strict = 1'b1;
            wait_frames(2);
            check_byte(1, 10, 8'h7F);
            check_byte(3, 46, 8'h44);
            if (led[2] !== 1'b0) fail("NACK LED on after scan found the OLED");
            if (errors == 0) $display("RESULT: PASS (scan, SWAP=%0d, addr=%h, frames=%0d)", SWAP, SLAVE_ADDR, frames);
            else             $display("RESULT: FAIL (%0d errors)", errors);
            $finish;
        end

        // 1. init sequence
        wait_led(0, 1'b1, 200000);
        if (cmd_n < 26) fail("too few init commands");
        for (k = 0; k < 26; k = k + 1)
            if (cmd_log[k] !== exp_init[k]) begin
                errors = errors + 1;
                $display("FAIL: init cmd %0d = %h, expected %h", k, cmd_log[k], exp_init[k]);
            end
        if (led[2] !== 1'b0) fail("NACK LED on after good init");
        rgb_color(0, color);
        if (color !== 3'b010) fail("LD4 not green with pull-ups");
        rgb_color(1, color);
        if (color !== 3'b010) fail("LD5 not green (normal, 0x3C)");

        // 2. text page
        wait_frames(2);
        check_byte(0, 0,   8'hFF);              // left border
        check_byte(3, 127, 8'hFF);              // right border
        check_byte(0, 50,  8'h01);              // top border row
        check_byte(7, 50,  8'h80);              // bottom border row
        check_byte(1, 10,  8'h7F);              // 'P' (line 1, char 1)
        check_byte(1, 11,  8'h09);
        check_byte(1, 12,  8'h09);
        check_byte(1, 13,  8'h09);
        check_byte(1, 14,  8'h06);
        check_byte(1, 15,  8'h00);              // gap column
        check_byte(3, 46,  8'h44);              // 'x' in "0x3C"
        check_byte(3, 47,  8'h28);
        check_byte(3, 48,  8'h10);
        check_byte(6, 4,   8'h3C);              // progress bar start
        for (k = 0; k < 24; k = k + 1) snap[k] = gd[4 * 128 + 58 + k];
        wait_frames(3);
        diff = 0;
        for (k = 0; k < 24; k = k + 1) if (snap[k] !== gd[4 * 128 + 58 + k]) diff = 1;
        if (!diff) fail("uptime digits did not change");
        if (led[1] === 1'bx) fail("heartbeat X");

        // 3. checkerboard page
        sw[0] = 1'b1;
        wait_frames(2);
        v0 = gd[0];
        if (v0 !== 8'h00 && v0 !== 8'hFF) fail("pattern corner not 00/FF");
        for (p = 0; p < 8; p = p + 1)
            for (c = 0; c < 128; c = c + 1)
                if (gd[p * 128 + c] !== ((((p ^ (c >> 3)) & 1) != 0) ? ~v0 : v0)) begin
                    errors = errors + 1;
                    if (errors < 10)
                        $display("FAIL: pattern page %0d col %0d = %h", p, c, gd[p * 128 + c]);
                end
        sw[0] = 1'b0;

        // 4. device absent -> NACK LED, then recovery
        ack_en = 1'b0;
        wait_led(2, 1'b1, 400000);
        if (led[0] !== 1'b0) fail("init LED still on after NACK");
        if (nack_stops == 0) fail("no STOP after address NACK");
        repeat (5000) @(posedge clk);
        ack_en = 1'b1;
        wait_led(0, 1'b1, 400000);
        if (led[2] !== 1'b0) fail("NACK LED stays on after recovery");
        wait_frames(1);

        // 4b. module that never ACKs + sw1 (ignore NACK): keeps streaming
        ack_en = 1'b0;
        sw[1]  = 1'b1;
        btn[0] = 1'b1;
        repeat (50) @(posedge clk);
        btn[0] = 1'b0;
        wait_led(0, 1'b1, 400000);
        wait_led(3, 1'b1, 400000);              // a full frame was sent
        if (led[2] !== 1'b1) fail("NACK LED off in ignore mode");
        sw[1]  = 1'b0;
        ack_en = 1'b1;
        btn[0] = 1'b1;
        repeat (50) @(posedge clk);
        btn[0] = 1'b0;
        wait_led(0, 1'b1, 400000);
        wait_frames(1);

        // 5. btn0 restart in the middle of a frame
        repeat (30000) @(posedge clk);
        strict = 1'b0;
        btn[0] = 1'b1;
        repeat (50) @(posedge clk);
        if (led[0] !== 1'b0) fail("btn0 did not reset");
        btn[0] = 1'b0;
        wait_led(0, 1'b1, 400000);
        wait_frames(1);
        strict = 1'b1;
        wait_frames(1);
        check_byte(1, 10, 8'h7F);

        // 6. SDA stuck low (for example an unpowered module): LD4 blue
        strict  = 1'b0;
        force sda_drv = 1'b1;
        wait_led(2, 1'b1, 400000);
        repeat (3000) @(posedge clk);
        rgb_color(0, color);
        if (color !== 3'b001) fail("LD4 not blue with SDA stuck low");
        release sda_drv;
        sda_drv = 1'b0;

        if (errors == 0) $display("RESULT: PASS (frames=%0d, nack_stops=%0d)", frames, nack_stops);
        else             $display("RESULT: FAIL (%0d errors)", errors);
        $finish;
    end
endmodule
