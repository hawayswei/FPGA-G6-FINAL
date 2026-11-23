// ============================================================================
// Module : acl_test_source
// Owner  : integrator
// Purpose: Stand-in for the accelerometer when no sensor is connected.
//          Produces a made-up 100 Hz data stream that repeats this script:
//            rest upright (z = +1 g)        REST_SAMPLES
//            free fall (about 0.1 g)        30 samples
//            impact (about 4 g)             5 samples
//            lying still (x = +1 g)         LIE_SAMPLES
//          so the fall detector, the system FSM, the Bluetooth alert and the
//          ILA recording can all be tried on the board without a sensor.
//          The data is synthetic; it says nothing about real falls.
// Clock  : clk_i (125 MHz system clock).
// Reset  : rst_n_i, synchronous, active low.
// ============================================================================
`timescale 1ns / 1ps

module acl_test_source #(
    parameter SAMPLE_CYCLES = 1250000,   // 100 Hz
    parameter REST_SAMPLES  = 1500,      // 15 s upright between falls
    parameter LIE_SAMPLES   = 600        // 6 s lying after the impact
) (
    input  wire               clk_i,
    input  wire               rst_n_i,
    output reg  signed [15:0] accel_x_o    = 16'sd0,
    output reg  signed [15:0] accel_y_o    = 16'sd0,
    output reg  signed [15:0] accel_z_o    = 16'sd250,
    output reg                data_valid_o = 1'b0
);

    localparam FALL_SAMPLES   = 30;
    localparam IMPACT_SAMPLES = 5;
    localparam T_FALL   = REST_SAMPLES;
    localparam T_IMPACT = T_FALL + FALL_SAMPLES;
    localparam T_LIE    = T_IMPACT + IMPACT_SAMPLES;
    localparam T_END    = T_LIE + LIE_SAMPLES;

    reg [31:0] div_cnt_r = 32'd0;
    reg [15:0] idx_r     = 16'd0;
    reg [7:0]  lfsr_r    = 8'hA5;        // small dither so the data is not constant

    wire signed [15:0] dither = {{13{lfsr_r[2]}}, lfsr_r[2:0]};   // -4 .. +3

    always @(posedge clk_i) begin
        if (!rst_n_i) begin
            accel_x_o    <= 16'sd0;
            accel_y_o    <= 16'sd0;
            accel_z_o    <= 16'sd250;
            data_valid_o <= 1'b0;
            div_cnt_r    <= 32'd0;
            idx_r        <= 16'd0;
            lfsr_r       <= 8'hA5;
        end else begin
            data_valid_o <= 1'b0;
            if (div_cnt_r == SAMPLE_CYCLES - 1) begin
                div_cnt_r    <= 32'd0;
                data_valid_o <= 1'b1;
                lfsr_r       <= {lfsr_r[6:0], lfsr_r[7] ^ lfsr_r[5] ^ lfsr_r[4] ^ lfsr_r[3]};
                idx_r        <= (idx_r == T_END - 1) ? 16'd0 : idx_r + 16'd1;
                if (idx_r < T_FALL) begin                 // upright
                    accel_x_o <= dither;
                    accel_y_o <= -dither;
                    accel_z_o <= 16'sd250 + dither;
                end else if (idx_r < T_IMPACT) begin      // free fall
                    accel_x_o <= 16'sd10 + dither;
                    accel_y_o <= -16'sd8;
                    accel_z_o <= 16'sd20 + dither;
                end else if (idx_r < T_LIE) begin         // impact
                    accel_x_o <= 16'sd450;
                    accel_y_o <= -16'sd300 + dither;
                    accel_z_o <= 16'sd900;
                end else begin                            // lying on the side
                    accel_x_o <= 16'sd250 + dither;
                    accel_y_o <= dither;
                    accel_z_o <= -dither;
                end
            end else begin
                div_cnt_r <= div_cnt_r + 32'd1;
            end
        end
    end

endmodule
