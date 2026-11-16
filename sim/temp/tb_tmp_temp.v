// ============================================================================
// Testbench : tb_tmp_temp
// DUT       : tmp_tmp3_reader + tmp_zone, with a short poll period
// Model     : behavioral Pmod TMP3 I2C slave (address 0x48, read only),
//             taken from the Lab 3 testbench.
// Checks    : 1. 36.5 C is read as 73 half-degrees, zone 2 (green)
//             2. 38.0 C -> zone 3 (orange) and one ev_high pulse
//             3. 39.0 C -> zone 4 (red), no second ev_high
//             4. hysteresis: 38.5 C stays in zone 4, 37.5 C drops to zone 3
//             5. 25.0 C -> steps down to zone 0 (purple), one ev_low pulse
//             6. -5.0 C is read as -10
//             7. sensor removed -> valid = 0, value kept, RGB LED off
// Run time  : finishes by itself in about 6 ms of simulated time.
// Expected  : prints "TB PASS".
// ============================================================================
`timescale 1ns / 1ps

module tb_tmp_temp;

    reg  clk_i = 1'b0, rst_n_i = 1'b0;
    wire scl, sda_low;
    tri1 sda;                             // bus pull-up
    wire signed [8:0] temp_x2;
    wire temp_valid, temp_update;
    wire [2:0] zone;
    wire ev_high, ev_low, rgb_r, rgb_g, rgb_b;

    integer errors = 0, n_high = 0, n_low = 0, n_upd = 0;

    assign sda = sda_low ? 1'b0 : 1'bz;

    tmp_tmp3_reader #(.QTR_CYCLES(8), .POLL_CYCLES(400)) u_reader (
        .clk_i (clk_i), .rst_n_i (rst_n_i),
        .scl_o (scl), .sda_low_o (sda_low), .sda_i (sda),
        .temp_x2_o (temp_x2), .valid_o (temp_valid), .update_o (temp_update)
    );

    tmp_zone u_zone (
        .clk_i (clk_i), .rst_n_i (rst_n_i),
        .temp_x2_i (temp_x2), .temp_valid_i (temp_valid), .temp_update_i (temp_update),
        .zone_o (zone), .ev_high_o (ev_high), .ev_low_o (ev_low),
        .rgb_r_o (rgb_r), .rgb_g_o (rgb_g), .rgb_b_o (rgb_b)
    );

    always #4 clk_i = ~clk_i;

    always @(posedge clk_i) begin
        if (ev_high)     n_high = n_high + 1;
        if (ev_low)      n_low  = n_low  + 1;
        if (temp_update) n_upd  = n_upd  + 1;
    end

    // ---- Pmod TMP3 slave model ---------------------------------------------
    reg [7:0] T_MSB = 8'd36;
    reg [7:0] T_LSB = 8'h80;
    reg       slave_en = 1'b1;

    localparam ST_IDLE = 0, ST_ADDR = 1, ST_ACK = 2, ST_TX = 3, ST_MACK = 4;
    integer st = ST_IDLE, cnt = 0, txcnt = 0;
    reg [7:0] sh = 8'd0, tx = 8'd0;
    reg       m_ack = 1'b0, s_low = 1'b0;
    assign sda = s_low ? 1'b0 : 1'bz;

    always @(negedge sda) if (scl === 1'b1) begin st = ST_ADDR; cnt = 0; sh = 8'd0; end   // START
    always @(posedge sda) if (scl === 1'b1) begin st = ST_IDLE; s_low = 1'b0; end         // STOP

    always @(posedge scl) begin
        case (st)
            ST_ADDR: begin sh = {sh[6:0], sda}; cnt = cnt + 1; end
            ST_MACK: m_ack = ~sda;
            default: ;
        endcase
    end

    always @(negedge scl) begin
        case (st)
            ST_ADDR: if (cnt == 8) begin
                if (slave_en && sh[7:1] == 7'h48 && sh[0]) begin s_low = 1'b1; st = ST_ACK; end
                else st = ST_IDLE;
            end
            ST_ACK: begin tx = T_MSB; txcnt = 1; s_low = ~tx[7]; st = ST_TX; end
            ST_TX: begin
                if (txcnt < 8) begin s_low = ~tx[7 - txcnt]; txcnt = txcnt + 1; end
                else begin s_low = 1'b0; st = ST_MACK; end
            end
            ST_MACK: begin
                if (m_ack) begin tx = T_LSB; txcnt = 1; s_low = ~tx[7]; st = ST_TX; m_ack = 1'b0; end
                else begin s_low = 1'b0; st = ST_IDLE; end
            end
            default: ;
        endcase
    end

    // ---- Helpers -------------------------------------------------------------
    task set_temp;                       // temperature in half-degrees
        input signed [8:0] t_x2;
        begin
            @(posedge temp_update);      // change between two reads
            T_MSB = t_x2[8:1];
            T_LSB = {t_x2[0], 7'd0};
        end
    endtask

    task wait_reads;
        input integer n;
        integer target;
        begin
            target = n_upd + n;
            while (n_upd < target) @(posedge clk_i);
            repeat (4) @(posedge clk_i);
        end
    endtask

    task expect_all;
        input signed [8:0] t_x2;
        input [2:0] z;
        input integer h, l;
        input [8*20-1:0] what;
        begin
            if (temp_x2 !== t_x2 || zone !== z || n_high != h || n_low != l) begin
                errors = errors + 1;
                $display("TB ERROR: %0s: temp_x2=%0d zone=%0d high=%0d low=%0d, expected %0d %0d %0d %0d",
                         what, temp_x2, zone, n_high, n_low, t_x2, z, h, l);
            end
        end
    endtask

    initial begin
        #40 rst_n_i = 1'b1;
        wait_reads(2);
        if (temp_valid !== 1'b1) begin errors = errors + 1; $display("TB ERROR: not valid"); end
        expect_all(9'sd73, 3'd2, 0, 0, "36.5 C");

        set_temp(9'sd76);  wait_reads(3); expect_all(9'sd76, 3'd3, 1, 0, "38.0 C");
        set_temp(9'sd78);  wait_reads(3); expect_all(9'sd78, 3'd4, 1, 0, "39.0 C");
        set_temp(9'sd77);  wait_reads(3); expect_all(9'sd77, 3'd4, 1, 0, "38.5 C hysteresis");
        set_temp(9'sd75);  wait_reads(3); expect_all(9'sd75, 3'd3, 1, 0, "37.5 C");
        set_temp(9'sd50);  wait_reads(6); expect_all(9'sd50, 3'd0, 1, 1, "25.0 C");
        set_temp(-9'sd10); wait_reads(3); expect_all(-9'sd10, 3'd0, 1, 1, "-5.0 C");

        // sensor removed
        @(posedge temp_update); slave_en = 1'b0;
        wait_reads(3);
        if (temp_valid !== 1'b0 || temp_x2 !== -9'sd10) begin
            errors = errors + 1;
            $display("TB ERROR: no sensor: valid=%b temp_x2=%0d", temp_valid, temp_x2);
        end
        repeat (70000) @(posedge clk_i);          // longer than one PWM period
        if (rgb_r !== 1'b0 || rgb_g !== 1'b0 || rgb_b !== 1'b0) begin
            errors = errors + 1; $display("TB ERROR: RGB LED not off without a sensor");
        end

        if (errors == 0) $display("TB PASS: TMP3 read, zones, hysteresis and events OK");
        else             $display("TB FAIL: %0d errors", errors);
        $finish;
    end

    initial begin
        #20000000;
        $display("TB FAIL: timeout");
        $finish;
    end

endmodule
