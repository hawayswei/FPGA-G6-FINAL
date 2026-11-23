// ============================================================================
// Testbench : tb_fall_detect
// DUT       : fall_detect + fall_param_lut (adult mode, 170 cm)
// Vectors   : fall_vectors.mem, made by "python tools/gen_fall_vectors.py"
//             from the Python model. Each line: posture_en, expected fall
//             flag, x, y, z. The file must be in the simulation run folder
//             (scripts/create_project.tcl adds it to the Vivado project).
// Checks    : the hardware reports a fall on exactly the same samples as the
//             Python model, for all scenarios in the vector file.
// Run time  : about 1.2 ms of simulated time ("run 2ms", never "run all" in the
//             Vivado MCP/Tcl console).
// Expected  : prints "TB PASS".
// ============================================================================
`timescale 1ns / 1ps

module tb_fall_detect;

    localparam MAX_VECTORS = 20000;

    reg                clk_i   = 1'b0;
    reg                rst_n_i = 1'b0;
    reg                sample_valid_i = 1'b0;
    reg  signed [15:0] accel_x_i = 16'sd0, accel_y_i = 16'sd0, accel_z_i = 16'sd0;
    reg                posture_en_i = 1'b0;
    wire [23:0]        lft_sq, uft_sq;
    wire [7:0]         window;
    wire               fall_o;
    wire [2:0]         state_o;
    wire [23:0]        mag_sq_o;
    wire               mag_valid_o;

    reg [55:0] vectors [0:MAX_VECTORS-1];
    integer    n, i, k;
    integer    errors = 0, falls = 0, expected_falls = 0;
    reg        fall_seen;

    fall_param_lut u_lut (
        .clk_i    (clk_i),
        .rst_n_i  (rst_n_i),
        .mode_i   (2'd0),
        .height_i (8'd170),
        .lft_sq_o (lft_sq),
        .uft_sq_o (uft_sq),
        .window_o (window)
    );

    fall_detect dut (
        .clk_i          (clk_i),
        .rst_n_i        (rst_n_i),
        .sample_valid_i (sample_valid_i),
        .accel_x_i      (accel_x_i),
        .accel_y_i      (accel_y_i),
        .accel_z_i      (accel_z_i),
        .lft_sq_i       (lft_sq),
        .uft_sq_i       (uft_sq),
        .window_i       (window),
        .posture_en_i   (posture_en_i),
        .fall_o         (fall_o),
        .state_o        (state_o),
        .mag_sq_o       (mag_sq_o),
        .mag_valid_o    (mag_valid_o)
    );

    always #4 clk_i = ~clk_i;        // 125 MHz

    initial begin
        for (k = 0; k < MAX_VECTORS; k = k + 1) vectors[k] = {56{1'bx}};
        $readmemh("fall_vectors.mem", vectors);
        n = 0;
        while (n < MAX_VECTORS && vectors[n][0] !== 1'bx) n = n + 1;
        if (n == 0) begin
            $display("TB FAIL: fall_vectors.mem not found or empty");
            $finish;
        end

        #40 rst_n_i = 1'b1;
        repeat (4) @(posedge clk_i);

        for (i = 0; i < n; i = i + 1) begin
            // one sample every 16 clocks (the real design has 1.25 million between samples)
            posture_en_i   <= vectors[i][52];
            accel_x_i      <= vectors[i][47:32];
            accel_y_i      <= vectors[i][31:16];
            accel_z_i      <= vectors[i][15:0];
            sample_valid_i <= 1'b1;
            @(posedge clk_i);
            sample_valid_i <= 1'b0;
            fall_seen = 1'b0;
            repeat (15) begin
                @(posedge clk_i);
                if (fall_o) fall_seen = 1'b1;
            end
            if (fall_seen) falls = falls + 1;
            if (vectors[i][48]) expected_falls = expected_falls + 1;
            if (fall_seen !== vectors[i][48]) begin
                errors = errors + 1;
                if (errors <= 10)
                    $display("TB ERROR: sample %0d fall=%b expected=%b state=%0d",
                             i, fall_seen, vectors[i][48], state_o);
            end
        end

        if (errors == 0 && falls > 0)
            $display("TB PASS: %0d samples, %0d falls, identical to the Python model", n, falls);
        else
            $display("TB FAIL: %0d errors, %0d falls (expected %0d)", errors, falls, expected_falls);
        $finish;
    end

endmodule
