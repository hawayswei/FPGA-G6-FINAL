// ============================================================================
// Module : tmp_zone
// Owner  : integrator
// Purpose: Turn the temperature into one of five zones with hysteresis, show
//          the zone as a color on an RGB LED (PWM), and raise one-shot events
//          when the temperature becomes too high or too low.
//            zone 0 : below T1          purple
//            zone 1 : T1 .. T2          blue
//            zone 2 : T2 .. T3          green  (normal)
//            zone 3 : T3 .. T4          orange
//            zone 4 : T4 and above      red
//          The zone moves up when temp >= the next boundary and down when
//          temp <= the lower boundary - HYST. It moves one zone per update.
//          Temperatures are in units of 0.5 C (37.5 C = 75).
//          Boundaries and colors are parameters: change them where the
//          module is instantiated.
// Clock  : clk_i (125 MHz system clock).
// Reset  : rst_n_i, synchronous, active low.
// ============================================================================
`timescale 1ns / 1ps

module tmp_zone #(
    parameter signed [8:0] T1   = 9'sd60,    // 30.0 C
    parameter signed [8:0] T2   = 9'sd68,    // 34.0 C
    parameter signed [8:0] T3   = 9'sd75,    // 37.5 C
    parameter signed [8:0] T4   = 9'sd77,    // 38.5 C
    parameter signed [8:0] HYST = 9'sd1,     // 0.5 C
    // colors as {R, G, B} duty, 0..255 (kept low: the board LEDs are very bright)
    parameter [23:0] COLOR0 = {8'd40, 8'd0,  8'd60},   // purple
    parameter [23:0] COLOR1 = {8'd0,  8'd0,  8'd60},   // blue
    parameter [23:0] COLOR2 = {8'd0,  8'd50, 8'd0},    // green
    parameter [23:0] COLOR3 = {8'd80, 8'd20, 8'd0},    // orange
    parameter [23:0] COLOR4 = {8'd80, 8'd0,  8'd0}     // red
) (
    input  wire              clk_i,
    input  wire              rst_n_i,
    input  wire signed [8:0] temp_x2_i,
    input  wire              temp_valid_i,     // sensor answered
    input  wire              temp_update_i,    // one-cycle pulse per reading
    output reg  [2:0]        zone_o      = 3'd2,
    output reg               ev_high_o   = 1'b0,   // entered zone 3 or above from below
    output reg               ev_low_o    = 1'b0,   // entered zone 0
    output reg               rgb_r_o     = 1'b0,
    output reg               rgb_g_o     = 1'b0,
    output reg               rgb_b_o     = 1'b0
);

    reg [15:0] pwm_cnt_r = 16'd0;
    reg [23:0] color;

    // boundary above and below the current zone
    reg signed [8:0] up_th, down_th;
    always @(*) begin
        case (zone_o)
            3'd0:    begin up_th = T1; down_th = T1; end
            3'd1:    begin up_th = T2; down_th = T1; end
            3'd2:    begin up_th = T3; down_th = T2; end
            3'd3:    begin up_th = T4; down_th = T3; end
            default: begin up_th = T4; down_th = T4; end
        endcase
        case (zone_o)
            3'd0:    color = COLOR0;
            3'd1:    color = COLOR1;
            3'd2:    color = COLOR2;
            3'd3:    color = COLOR3;
            default: color = COLOR4;
        endcase
    end

    always @(posedge clk_i) begin
        if (!rst_n_i) begin
            zone_o    <= 3'd2;
            ev_high_o <= 1'b0;
            ev_low_o  <= 1'b0;
        end else begin
            ev_high_o <= 1'b0;
            ev_low_o  <= 1'b0;
            if (temp_update_i && temp_valid_i) begin
                if (zone_o != 3'd4 && temp_x2_i >= up_th) begin
                    zone_o <= zone_o + 3'd1;
                    if (zone_o == 3'd2) ev_high_o <= 1'b1;
                end else if (zone_o != 3'd0 && temp_x2_i <= down_th - HYST) begin
                    zone_o <= zone_o - 3'd1;
                    if (zone_o == 3'd1) ev_low_o <= 1'b1;
                end
            end
        end
    end

    // PWM at about 1.9 kHz; LED off when the sensor does not answer
    always @(posedge clk_i) begin
        pwm_cnt_r <= pwm_cnt_r + 16'd1;
        rgb_r_o   <= temp_valid_i && (pwm_cnt_r[15:8] < color[23:16]);
        rgb_g_o   <= temp_valid_i && (pwm_cnt_r[15:8] < color[15:8]);
        rgb_b_o   <= temp_valid_i && (pwm_cnt_r[15:8] < color[7:0]);
    end

endmodule
