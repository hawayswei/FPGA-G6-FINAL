// ============================================================================
// Testbench : tb_acl_adxl362_ctrl
// DUT       : acl_adxl362_ctrl with shortened timing parameters
// Model     : behavioral ADXL362 (commands 0x0A write / 0x0B read, register
//             file, soft reset, data registers read 0 unless POWER_CTL = 0x02).
//             While "present" = 0 the model is silent and MISO is pulled high,
//             like an unplugged sensor.
// Checks    : 1. no sensor  -> dev_ok_o stays 0 and no data_valid_o pulses
//             2. sensor on  -> soft reset written, dev_ok_o = 1,
//                              FILTER_CTL = 0x93, POWER_CTL = 0x02
//             3. X/Y/Z values (positive and negative) arrive correctly
//             4. sample period equals SAMPLE_CYCLES
//             5. new sensor values show up on the next samples
// Run time  : finishes by itself in under 300 us ("run 300us", never "run all"
//             in the Vivado MCP/Tcl console).
// Expected  : prints "TB PASS".
// ============================================================================
`timescale 1ns / 1ps

module tb_acl_adxl362_ctrl;

    localparam SAMPLE_CYCLES = 2000;

    reg  clk_i   = 1'b0;
    reg  rst_n_i = 1'b0;
    wire cs_n_o, sclk_o, mosi_o, miso_i;
    wire signed [15:0] accel_x_o, accel_y_o, accel_z_o;
    wire data_valid_o, dev_ok_o;

    integer errors      = 0;
    integer valid_count = 0;
    time    t_prev = 0, t_last = 0;

    acl_adxl362_ctrl #(
        .HALF_DIV       (4),
        .POWERUP_CYCLES (200),
        .RESET_CYCLES   (100),
        .SAMPLE_CYCLES  (SAMPLE_CYCLES),
        .CS_GAP_CYCLES  (4)
    ) dut (
        .clk_i        (clk_i),
        .rst_n_i      (rst_n_i),
        .cs_n_o       (cs_n_o),
        .sclk_o       (sclk_o),
        .mosi_o       (mosi_o),
        .miso_i       (miso_i),
        .accel_x_o    (accel_x_o),
        .accel_y_o    (accel_y_o),
        .accel_z_o    (accel_z_o),
        .data_valid_o (data_valid_o),
        .dev_ok_o     (dev_ok_o)
    );

    always #4 clk_i = ~clk_i;        // 125 MHz

    // ---- ADXL362 behavioral model -----------------------------------------
    reg        present = 1'b0;
    reg [7:0]  regs [0:63];
    reg [7:0]  sh_in = 8'h00, sh_out = 8'h00, cmd = 8'h00, addr = 8'h00;
    reg        byte_ready = 1'b0;
    integer    bitn = 0, byten = 0, soft_resets = 0, k;

    assign miso_i = (present && !cs_n_o) ? sh_out[7] : 1'b1;   // pull-up when idle

    initial begin
        for (k = 0; k < 64; k = k + 1) regs[k] = 8'h00;
        regs[8'h00] = 8'hAD;         // DEVID_AD
        regs[8'h2C] = 8'h13;         // FILTER_CTL reset value
    end

    task set_xyz;
        input signed [15:0] x, y, z;
        begin
            regs[8'h0E] = x[7:0];  regs[8'h0F] = x[15:8];
            regs[8'h10] = y[7:0];  regs[8'h11] = y[15:8];
            regs[8'h12] = z[7:0];  regs[8'h13] = z[15:8];
        end
    endtask

    always @(negedge cs_n_o) begin
        bitn = 0; byten = 0; sh_out = 8'h00; byte_ready = 1'b0;
    end

    always @(posedge sclk_o) if (!cs_n_o) begin
        sh_in = {sh_in[6:0], mosi_o};
        bitn  = bitn + 1;
        if (bitn == 8) begin
            bitn = 0;
            if      (byten == 0) cmd  = sh_in;
            else if (byten == 1) addr = sh_in;
            else if (cmd == 8'h0A && present) begin
                if (addr == 8'h1F && sh_in == 8'h52) begin
                    soft_resets  = soft_resets + 1;
                    regs[8'h2C]  = 8'h13;
                    regs[8'h2D]  = 8'h00;
                end else begin
                    regs[addr[5:0]] = sh_in;
                end
                addr = addr + 8'd1;
            end
            byten      = byten + 1;
            byte_ready = 1'b1;
        end
    end

    always @(negedge sclk_o) if (!cs_n_o) begin
        if (byte_ready) begin
            byte_ready = 1'b0;
            if (cmd == 8'h0B && byten >= 2) begin
                // data registers are only alive in measurement mode
                if (addr >= 8'h0E && addr <= 8'h13 && regs[8'h2D] != 8'h02) sh_out = 8'h00;
                else                                                        sh_out = regs[addr[5:0]];
                addr = addr + 8'd1;
            end else begin
                sh_out = 8'h00;
            end
        end else begin
            sh_out = {sh_out[6:0], 1'b0};
        end
    end

    // ---- Bookkeeping ------------------------------------------------------
    always @(posedge clk_i) if (data_valid_o) begin
        valid_count = valid_count + 1;
        t_prev = t_last;
        t_last = $time;
    end

    task check_xyz;
        input signed [15:0] x, y, z;
        begin
            if (accel_x_o !== x || accel_y_o !== y || accel_z_o !== z) begin
                errors = errors + 1;
                $display("TB ERROR: got x=%0d y=%0d z=%0d, expected %0d %0d %0d",
                         accel_x_o, accel_y_o, accel_z_o, x, y, z);
            end
        end
    endtask

    task wait_valid;
        input integer n;
        integer target;
        begin
            target = valid_count + n;
            while (valid_count < target) @(posedge clk_i);
            @(posedge clk_i);
        end
    endtask

    initial begin
        set_xyz(16'sd291, -16'sd100, 16'sd250);
        #40 rst_n_i = 1'b1;

        // 1. sensor absent: several init attempts must all fail
        #(1500 * 8);
        if (dev_ok_o !== 1'b0 || valid_count != 0) begin
            errors = errors + 1;
            $display("TB ERROR: dev_ok or data_valid active without a sensor");
        end

        // 2. plug the sensor in while the DUT waits before a new init attempt
        //    (step 0 = SOFT_RESET, state 0 = waiting with CS high)
        @(posedge clk_i);
        while (!(dut.step_r == 3'd0 && dut.state_r == 3'd0)) @(posedge clk_i);
        present = 1'b1;
        wait (dev_ok_o === 1'b1);
        wait_valid(1);
        if (soft_resets < 1) begin
            errors = errors + 1; $display("TB ERROR: no soft reset seen");
        end
        if (regs[8'h2C] !== 8'h93 || regs[8'h2D] !== 8'h02) begin
            errors = errors + 1;
            $display("TB ERROR: FILTER_CTL=%h POWER_CTL=%h", regs[8'h2C], regs[8'h2D]);
        end

        // 3. values, 4. sample period
        check_xyz(16'sd291, -16'sd100, 16'sd250);
        wait_valid(2);
        if (t_last - t_prev != SAMPLE_CYCLES * 8) begin
            errors = errors + 1;
            $display("TB ERROR: sample period %0d ns, expected %0d ns",
                     t_last - t_prev, SAMPLE_CYCLES * 8);
        end

        // 5. new values (full 12-bit range ends)
        @(posedge cs_n_o);
        set_xyz(-16'sd2048, 16'sd2047, -16'sd1);
        wait_valid(2);
        check_xyz(-16'sd2048, 16'sd2047, -16'sd1);

        if (errors == 0) $display("TB PASS: init, ID check, %0d samples OK", valid_count);
        else             $display("TB FAIL: %0d errors", errors);
        $finish;
    end

    initial begin
        #300000;
        $display("TB FAIL: timeout (dev_ok=%b valid_count=%0d)", dev_ok_o, valid_count);
        $finish;
    end

endmodule
