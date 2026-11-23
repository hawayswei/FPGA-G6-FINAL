// ============================================================================
// Module : fall_param_lut
// Owner  : integrator
// Purpose: Personalized fall-detection parameters from the user's mode and
//          height (both set over Bluetooth).
//            mode   -> free-fall and impact thresholds (squared, 1 g = 250 LSB)
//            height -> samples allowed between free fall and impact
//                      (a taller person falls for longer: t = sqrt(2h/g))
//          ALL NUMBERS HERE ARE FIRST GUESSES. Replace them with values found
//          from the recorded trials (tools/analyze_trials.py), and keep
//          tools/fall_model.py param_lut() identical.
// Clock  : clk_i (125 MHz system clock). Outputs are registered.
// Reset  : rst_n_i, synchronous, active low.
// ============================================================================
`timescale 1ns / 1ps

module fall_param_lut (
    input  wire        clk_i,
    input  wire        rst_n_i,
    input  wire [1:0]  mode_i,       // 0 = adult, 1 = elderly, 2 = sport
    input  wire [7:0]  height_i,     // cm
    output reg  [23:0] lft_sq_o = 24'd15625,
    output reg  [23:0] uft_sq_o = 24'd390625,
    output reg  [7:0]  window_o = 8'd70
);

    localparam [1:0] MODE_ADULT   = 2'd0;
    localparam [1:0] MODE_ELDERLY = 2'd1;
    localparam [1:0] MODE_SPORT   = 2'd2;

    // thresholds as (g * 250)^2
    localparam [23:0] LFT_ADULT   = 24'd15625;    // 0.5 g
    localparam [23:0] UFT_ADULT   = 24'd390625;   // 2.5 g
    localparam [23:0] LFT_ELDERLY = 24'd22500;    // 0.6 g (more sensitive)
    localparam [23:0] UFT_ELDERLY = 24'd250000;   // 2.0 g
    localparam [23:0] LFT_SPORT   = 24'd10000;    // 0.4 g (less sensitive)
    localparam [23:0] UFT_SPORT   = 24'd562500;   // 3.0 g

    // window in samples (10 ms each) by height band
    localparam [7:0] HEIGHT_BAND_1 = 8'd150;      // cm
    localparam [7:0] HEIGHT_BAND_2 = 8'd165;
    localparam [7:0] HEIGHT_BAND_3 = 8'd180;
    localparam [7:0] WINDOW_0 = 8'd60;            // below 150 cm
    localparam [7:0] WINDOW_1 = 8'd65;            // 150..164 cm
    localparam [7:0] WINDOW_2 = 8'd70;            // 165..179 cm
    localparam [7:0] WINDOW_3 = 8'd75;            // 180 cm and above

    always @(posedge clk_i) begin
        if (!rst_n_i) begin
            lft_sq_o <= LFT_ADULT;
            uft_sq_o <= UFT_ADULT;
            window_o <= WINDOW_2;
        end else begin
            case (mode_i)
                MODE_ELDERLY: begin lft_sq_o <= LFT_ELDERLY; uft_sq_o <= UFT_ELDERLY; end
                MODE_SPORT:   begin lft_sq_o <= LFT_SPORT;   uft_sq_o <= UFT_SPORT;   end
                default:      begin lft_sq_o <= LFT_ADULT;   uft_sq_o <= UFT_ADULT;   end
            endcase
            if      (height_i < HEIGHT_BAND_1) window_o <= WINDOW_0;
            else if (height_i < HEIGHT_BAND_2) window_o <= WINDOW_1;
            else if (height_i < HEIGHT_BAND_3) window_o <= WINDOW_2;
            else                               window_o <= WINDOW_3;
        end
    end

endmodule
