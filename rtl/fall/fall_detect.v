// ============================================================================
// Module : fall_detect
// Owner  : integrator
// Purpose: Threshold-based fall detection from 3-axis acceleration only.
//          Works on the squared magnitude m = x^2 + y^2 + z^2 (no square root).
//          Phases, advanced once per sample:
//            IDLE   : m < lft_sq_i for FF_MIN_SAMPLES samples in a row
//                     (free fall) -> ARMED
//            ARMED  : m > uft_sq_i within window_i samples (impact) -> SETTLE
//                     window expires without impact -> IDLE
//            SETTLE : wait SETTLE_SAMPLES for the bouncing to end
//            STILL  : for STILL_SAMPLES count samples whose m is outside
//                     [STILL_LO_SQ, STILL_HI_SQ] (not resting at about 1 g)
//            EVAL   : fall if bad samples <= STILL_MAX_BAD, and (only when
//                     posture_en_i = 1) the gravity direction changed:
//                     dot(reference before the fall, average now) < POSTURE_DOT_MAX
//          fall_o is a one-cycle pulse.
// Units  : 1 g is about 250 LSB (ADXL362 at +-8 g), so 1 g^2 = 62500.
//          Sample rate 100 Hz, so 100 samples = 1 s.
// Model  : tools/fall_model.py is a bit-exact Python copy of this file.
//          Change both together, then run tools/gen_fall_vectors.py and
//          sim/fall/tb_fall_detect.v.
// Clock  : clk_i (125 MHz system clock).
// Reset  : rst_n_i, synchronous, active low.
// ============================================================================
`timescale 1ns / 1ps

module fall_detect #(
    parameter               FF_MIN_SAMPLES  = 5,          // 50 ms of free fall arms the detector
    parameter               SETTLE_SAMPLES  = 100,        // 1 s
    parameter               STILL_SAMPLES   = 200,        // 2 s
    parameter               STILL_MAX_BAD   = 30,         // tolerated moving samples in STILL
    parameter [23:0]        STILL_LO_SQ     = 24'd40000,  // (0.8 g)^2
    parameter [23:0]        STILL_HI_SQ     = 24'd90000,  // (1.2 g)^2
    parameter signed [31:0] POSTURE_DOT_MAX = 32'sd44000, // cos(45 deg) * (1 g)^2
    parameter               REF_PERIOD      = 100,        // samples between gravity snapshots
    parameter               AVG_SHIFT       = 5           // gravity low-pass: 2^5 samples
) (
    input  wire               clk_i,
    input  wire               rst_n_i,
    input  wire               sample_valid_i,   // one-cycle pulse per sample
    input  wire signed [15:0] accel_x_i,
    input  wire signed [15:0] accel_y_i,
    input  wire signed [15:0] accel_z_i,
    input  wire [23:0]        lft_sq_i,         // lower (free-fall) threshold, squared
    input  wire [23:0]        uft_sq_i,         // upper (impact) threshold, squared
    input  wire [7:0]         window_i,         // samples allowed between free fall and impact
    input  wire               posture_en_i,     // 1 = also require a posture change
    output reg                fall_o      = 1'b0,
    output reg  [2:0]         state_o     = 3'd0,
    output reg  [23:0]        mag_sq_o    = 24'd0,
    output reg                mag_valid_o = 1'b0  // two cycles after sample_valid_i
);

    localparam [2:0] ST_IDLE   = 3'd0;
    localparam [2:0] ST_ARMED  = 3'd1;
    localparam [2:0] ST_SETTLE = 3'd2;
    localparam [2:0] ST_STILL  = 3'd3;
    localparam [2:0] ST_EVAL   = 3'd4;

    // ---- Stage 1: squared magnitude, saturated to 24 bits -------------------
    // Two register stages (products, then sum) so the multipliers meet timing.
    // Samples are 10 ms apart, so the extra clock does not matter.
    reg signed [15:0] x_r = 16'sd0, y_r = 16'sd0, z_r = 16'sd0;
    reg signed [31:0] xx_r = 32'sd0, yy_r = 32'sd0, zz_r = 32'sd0;
    reg               sq_valid_r = 1'b0;
    wire       [33:0] sum_sq = {2'b00, xx_r} + {2'b00, yy_r} + {2'b00, zz_r};

    always @(posedge clk_i) begin
        if (!rst_n_i) begin
            mag_sq_o    <= 24'd0;
            mag_valid_o <= 1'b0;
            sq_valid_r  <= 1'b0;
            x_r <= 16'sd0; y_r <= 16'sd0; z_r <= 16'sd0;
            xx_r <= 32'sd0; yy_r <= 32'sd0; zz_r <= 32'sd0;
        end else begin
            sq_valid_r  <= sample_valid_i;
            mag_valid_o <= sq_valid_r;
            if (sample_valid_i) begin
                xx_r <= accel_x_i * accel_x_i;
                yy_r <= accel_y_i * accel_y_i;
                zz_r <= accel_z_i * accel_z_i;
                x_r <= accel_x_i; y_r <= accel_y_i; z_r <= accel_z_i;
            end
            if (sq_valid_r)
                mag_sq_o <= (|sum_sq[33:24]) ? 24'hFFFFFF : sum_sq[23:0];
        end
    end

    // ---- Gravity estimate: low-pass with AVG_SHIFT fractional bits ----------
    reg signed [23:0] acc_x_r = 24'sd0, acc_y_r = 24'sd0, acc_z_r = 24'sd0;
    wire signed [23:0] avg_x = acc_x_r >>> AVG_SHIFT;
    wire signed [23:0] avg_y = acc_y_r >>> AVG_SHIFT;
    wire signed [23:0] avg_z = acc_z_r >>> AVG_SHIFT;

    // Snapshots of the gravity estimate taken while idle
    reg signed [15:0] ref_new_x_r = 16'sd0, ref_new_y_r = 16'sd0, ref_new_z_r = 16'sd0;
    reg signed [15:0] ref_old_x_r = 16'sd0, ref_old_y_r = 16'sd0, ref_old_z_r = 16'sd0;
    reg signed [15:0] ref_x_r     = 16'sd0, ref_y_r     = 16'sd0, ref_z_r     = 16'sd0;

    // Dot product of the held reference and the current estimate (registered;
    // it is stable long before the next sample uses it)
    wire signed [15:0] avg_x16 = avg_x[15:0];
    wire signed [15:0] avg_y16 = avg_y[15:0];
    wire signed [15:0] avg_z16 = avg_z[15:0];
    reg signed [31:0] dx_r = 32'sd0, dy_r = 32'sd0, dz_r = 32'sd0;
    reg signed [47:0] dot_r = 48'sd0;
    always @(posedge clk_i) begin
        dx_r  <= ref_x_r * avg_x16;
        dy_r  <= ref_y_r * avg_y16;
        dz_r  <= ref_z_r * avg_z16;
        dot_r <= dx_r + dy_r + dz_r;
    end

    // ---- Stage 2: detector FSM, one step per sample -------------------------
    reg [7:0]  ff_cnt_r   = 8'd0;
    reg [7:0]  win_cnt_r  = 8'd0;
    reg [15:0] cnt_r      = 16'd0;
    reg [15:0] bad_cnt_r  = 16'd0;
    reg [15:0] ref_cnt_r  = 16'd0;

    wire low_m   = (mag_sq_o < lft_sq_i);
    wire high_m  = (mag_sq_o > uft_sq_i);
    wire moving  = (mag_sq_o < STILL_LO_SQ) || (mag_sq_o > STILL_HI_SQ);

    always @(posedge clk_i) begin
        if (!rst_n_i) begin
            fall_o    <= 1'b0;
            state_o   <= ST_IDLE;
            ff_cnt_r  <= 8'd0;
            win_cnt_r <= 8'd0;
            cnt_r     <= 16'd0;
            bad_cnt_r <= 16'd0;
            ref_cnt_r <= 16'd0;
            acc_x_r <= 24'sd0; acc_y_r <= 24'sd0; acc_z_r <= 24'sd0;
            ref_new_x_r <= 16'sd0; ref_new_y_r <= 16'sd0; ref_new_z_r <= 16'sd0;
            ref_old_x_r <= 16'sd0; ref_old_y_r <= 16'sd0; ref_old_z_r <= 16'sd0;
            ref_x_r     <= 16'sd0; ref_y_r     <= 16'sd0; ref_z_r     <= 16'sd0;
        end else begin
            fall_o <= 1'b0;
            if (mag_valid_o) begin
                // gravity low-pass (uses the sample latched in stage 1)
                acc_x_r <= acc_x_r + x_r - avg_x;
                acc_y_r <= acc_y_r + y_r - avg_y;
                acc_z_r <= acc_z_r + z_r - avg_z;

                case (state_o)
                    ST_IDLE: begin
                        // periodic gravity snapshots; the older one is 1..2 periods old
                        if (ref_cnt_r == REF_PERIOD - 1) begin
                            ref_cnt_r   <= 16'd0;
                            ref_old_x_r <= ref_new_x_r; ref_old_y_r <= ref_new_y_r; ref_old_z_r <= ref_new_z_r;
                            ref_new_x_r <= avg_x16;     ref_new_y_r <= avg_y16;     ref_new_z_r <= avg_z16;
                        end else begin
                            ref_cnt_r <= ref_cnt_r + 16'd1;
                        end

                        if (low_m) begin
                            if (ff_cnt_r + 8'd1 >= FF_MIN_SAMPLES) begin
                                state_o   <= ST_ARMED;
                                win_cnt_r <= window_i;
                                ff_cnt_r  <= 8'd0;
                                ref_x_r   <= ref_old_x_r; ref_y_r <= ref_old_y_r; ref_z_r <= ref_old_z_r;
                            end else begin
                                ff_cnt_r <= ff_cnt_r + 8'd1;
                            end
                        end else begin
                            ff_cnt_r <= 8'd0;
                        end
                    end

                    ST_ARMED: begin
                        if (high_m) begin
                            state_o <= ST_SETTLE;
                            cnt_r   <= SETTLE_SAMPLES;
                        end else if (low_m) begin
                            win_cnt_r <= window_i;            // still falling
                        end else if (win_cnt_r == 8'd0) begin
                            state_o <= ST_IDLE;
                        end else begin
                            win_cnt_r <= win_cnt_r - 8'd1;
                        end
                    end

                    ST_SETTLE: begin
                        if (cnt_r <= 16'd1) begin
                            state_o   <= ST_STILL;
                            cnt_r     <= STILL_SAMPLES;
                            bad_cnt_r <= 16'd0;
                        end else begin
                            cnt_r <= cnt_r - 16'd1;
                        end
                    end

                    ST_STILL: begin
                        if (moving && bad_cnt_r != 16'hFFFF)
                            bad_cnt_r <= bad_cnt_r + 16'd1;
                        if (cnt_r <= 16'd1) state_o <= ST_EVAL;
                        else                cnt_r   <= cnt_r - 16'd1;
                    end

                    ST_EVAL: begin
                        if (bad_cnt_r <= STILL_MAX_BAD &&
                            (!posture_en_i || dot_r < POSTURE_DOT_MAX))
                            fall_o <= 1'b1;
                        state_o   <= ST_IDLE;
                        ref_cnt_r <= 16'd0;
                    end

                    default: state_o <= ST_IDLE;
                endcase
            end
        end
    end

endmodule
