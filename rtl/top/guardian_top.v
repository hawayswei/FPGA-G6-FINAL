// ============================================================================
// Module : guardian_top
// Owner  : integrator (only the integrator edits this file)
// Purpose: Top level of the Invisible Guardian (fall detection) project.
//          accelerometer (or test source) -> fall detector -> system FSM
//          -> LEDs and Bluetooth messages; Bluetooth commands set the user
//          mode and height; TMP3 temperature -> RGB LED and Bluetooth events.
//          An ILA records the acceleration stream for the fall experiments.
// Clock  : sysclk_i = 125 MHz (PYNQ-Z2 pin H16). All logic uses this clock.
// Reset  : synchronous, active-low rst_n from button btn_i[3].
//
// Controls
//   btn_i[0] : user button. ASK: short press = I am OK (cancel).
//              ALARM: short press = clear. Any time: hold 2 s = manual SOS.
//   btn_i[3] : reset
//   sw_i[0]  : 1 = use the built-in test data instead of the sensor
//   sw_i[1]  : 1 = fall detector also requires a posture change
// Indicators
//   led_o[0] : heartbeat, about 1 Hz
//   led_o[1] : acceleration source OK (sensor ID read, or test data selected)
//   led_o[2] : blinks while asking "Are you OK?"
//   led_o[3] : ALARM
//   LD4 (RGB): temperature zone color (off when the TMP3 does not answer)
//   LD5 blue : fall detector is busy (free fall seen, checking impact/stillness)
//
// Everything that is likely to be tuned (times, texts, colors) is a
// parameter of the sub-modules and is set in the "Tuning" section below or
// in rtl/fall/fall_param_lut.v (thresholds). See docs/TUNING.md.
// ============================================================================
`timescale 1ns / 1ps

module guardian_top (
    input  wire       sysclk_i,     // 125 MHz board clock
    input  wire [3:0] btn_i,        // push buttons, 1 = pressed
    input  wire [1:0] sw_i,         // slide switches
    output wire [3:0] led_o,        // user LEDs
    output wire       led4_r_o,     // RGB LED LD4
    output wire       led4_g_o,
    output wire       led4_b_o,
    output wire       led5_b_o,     // RGB LED LD5, blue only
    // Pmod ACL2 (ADXL362) on Pmod A, top row
    output wire       acl_cs_n_o,
    output wire       acl_mosi_o,
    input  wire       acl_miso_i,
    output wire       acl_sclk_o,
    // Bluetooth module (UART) on Pmod A, bottom row
    output wire       bt_tx_o,      // FPGA -> module RXD
    input  wire       bt_rx_i,      // module TXD -> FPGA
    // Pmod TMP3 (I2C) on Pmod B
    output wire       tmp_scl_o,
    inout  wire       tmp_sda_io
);

    // ---- Tuning ---------------------------------------------------------------
    localparam CLK_HZ          = 125000000;
    localparam ASK_SECONDS     = 10;           // time to answer "Are you OK?"
    localparam REPEAT_SECONDS  = 5;            // alert repeat period in ALARM
    localparam LONG_PRESS_CYC  = 2 * CLK_HZ;   // hold time for manual SOS
    localparam UART_CLKS_PER_BIT = 13021;      // 9600 baud

    // ---- Reset, heartbeat, switches -----------------------------------------
    wire rst_n;
    wire beat;
    reg  [1:0] sw_s1_r = 2'b00, sw_s2_r = 2'b00;
    reg  [24:0] blink_cnt_r = 25'd0;           // bit 24 toggles at about 3.7 Hz

    ctrl_reset_sync u_reset_sync (
        .clk_i     (sysclk_i),
        .rst_btn_i (btn_i[3]),
        .rst_n_o   (rst_n)
    );

    ctrl_heartbeat #(.WIDTH(27)) u_heartbeat (
        .clk_i   (sysclk_i),
        .rst_n_i (rst_n),
        .beat_o  (beat)
    );

    always @(posedge sysclk_i) begin
        sw_s1_r     <= sw_i;
        sw_s2_r     <= sw_s1_r;
        blink_cnt_r <= blink_cnt_r + 25'd1;
    end
    wire use_test_data = sw_s2_r[0];
    wire posture_en    = sw_s2_r[1];

    // ---- Acceleration source ------------------------------------------------
    wire signed [15:0] sen_x, sen_y, sen_z, tst_x, tst_y, tst_z;
    wire               sen_valid, sen_dev_ok, tst_valid;

    acl_adxl362_ctrl u_accel (
        .clk_i        (sysclk_i),
        .rst_n_i      (rst_n),
        .cs_n_o       (acl_cs_n_o),
        .sclk_o       (acl_sclk_o),
        .mosi_o       (acl_mosi_o),
        .miso_i       (acl_miso_i),
        .accel_x_o    (sen_x),
        .accel_y_o    (sen_y),
        .accel_z_o    (sen_z),
        .data_valid_o (sen_valid),
        .dev_ok_o     (sen_dev_ok)
    );

    acl_test_source u_test_source (
        .clk_i        (sysclk_i),
        .rst_n_i      (rst_n),
        .accel_x_o    (tst_x),
        .accel_y_o    (tst_y),
        .accel_z_o    (tst_z),
        .data_valid_o (tst_valid)
    );

    reg signed [15:0] accel_x = 16'sd0, accel_y = 16'sd0, accel_z = 16'sd0;
    reg               accel_valid = 1'b0;
    always @(posedge sysclk_i) begin
        accel_x     <= use_test_data ? tst_x     : sen_x;
        accel_y     <= use_test_data ? tst_y     : sen_y;
        accel_z     <= use_test_data ? tst_z     : sen_z;
        accel_valid <= use_test_data ? tst_valid : sen_valid;
    end
    wire accel_ok = use_test_data | sen_dev_ok;

    // ---- Bluetooth: commands in ---------------------------------------------
    wire [7:0] bt_rx_data;
    wire       bt_rx_valid;
    wire [1:0] user_mode;
    wire [7:0] user_height;
    wire       cfg_update;

    bt_uart_rx #(.CLKS_PER_BIT(UART_CLKS_PER_BIT)) u_bt_rx (
        .clk_i   (sysclk_i),
        .rst_n_i (rst_n),
        .rx_i    (bt_rx_i),
        .data_o  (bt_rx_data),
        .valid_o (bt_rx_valid)
    );

    bt_cmd_parser u_bt_parser (
        .clk_i        (sysclk_i),
        .rst_n_i      (rst_n),
        .rx_data_i    (bt_rx_data),
        .rx_valid_i   (bt_rx_valid),
        .mode_o       (user_mode),
        .height_o     (user_height),
        .cfg_update_o (cfg_update)
    );

    // ---- Fall detection -------------------------------------------------------
    wire [23:0] lft_sq, uft_sq, mag_sq;
    wire [7:0]  fall_window;
    wire        fall_pulse, mag_valid;
    wire [2:0]  fall_state;

    fall_param_lut u_fall_lut (
        .clk_i    (sysclk_i),
        .rst_n_i  (rst_n),
        .mode_i   (user_mode),
        .height_i (user_height),
        .lft_sq_o (lft_sq),
        .uft_sq_o (uft_sq),
        .window_o (fall_window)
    );

    fall_detect u_fall_detect (
        .clk_i          (sysclk_i),
        .rst_n_i        (rst_n),
        .sample_valid_i (accel_valid),
        .accel_x_i      (accel_x),
        .accel_y_i      (accel_y),
        .accel_z_i      (accel_z),
        .lft_sq_i       (lft_sq),
        .uft_sq_i       (uft_sq),
        .window_i       (fall_window),
        .posture_en_i   (posture_en),
        .fall_o         (fall_pulse),
        .state_o        (fall_state),
        .mag_sq_o       (mag_sq),
        .mag_valid_o    (mag_valid)
    );

    // ---- User button and system FSM -----------------------------------------
    wire       btn_short, btn_long, btn_held;
    wire [1:0] sys_state;
    wire [7:0] ask_left;
    wire       alarm_sos, ev_ask, ev_fall, ev_sos, ev_ok;

    ctrl_button #(.LONG_CYCLES(LONG_PRESS_CYC)) u_button (
        .clk_i   (sysclk_i),
        .rst_n_i (rst_n),
        .btn_i   (btn_i[0]),
        .short_o (btn_short),
        .long_o  (btn_long),
        .held_o  (btn_held)
    );

    ctrl_guardian_fsm #(
        .CYCLES_PER_SECOND (CLK_HZ),
        .ASK_SECONDS       (ASK_SECONDS),
        .REPEAT_SECONDS    (REPEAT_SECONDS)
    ) u_fsm (
        .clk_i       (sysclk_i),
        .rst_n_i     (rst_n),
        .fall_i      (fall_pulse),
        .btn_short_i (btn_short),
        .btn_long_i  (btn_long),
        .state_o     (sys_state),
        .ask_left_o  (ask_left),
        .alarm_sos_o (alarm_sos),
        .ev_ask_o    (ev_ask),
        .ev_fall_o   (ev_fall),
        .ev_sos_o    (ev_sos),
        .ev_ok_o     (ev_ok)
    );

    // ---- Temperature ----------------------------------------------------------
    wire              tmp_sda_low;
    wire signed [8:0] temp_x2;
    wire              temp_valid, temp_update, ev_temp_high, ev_temp_low;
    wire [2:0]        temp_zone;

    assign tmp_sda_io = tmp_sda_low ? 1'b0 : 1'bz;     // open drain

    tmp_tmp3_reader u_tmp_reader (
        .clk_i     (sysclk_i),
        .rst_n_i   (rst_n),
        .scl_o     (tmp_scl_o),
        .sda_low_o (tmp_sda_low),
        .sda_i     (tmp_sda_io),
        .temp_x2_o (temp_x2),
        .valid_o   (temp_valid),
        .update_o  (temp_update)
    );

    tmp_zone u_tmp_zone (
        .clk_i         (sysclk_i),
        .rst_n_i       (rst_n),
        .temp_x2_i     (temp_x2),
        .temp_valid_i  (temp_valid),
        .temp_update_i (temp_update),
        .zone_o        (temp_zone),
        .ev_high_o     (ev_temp_high),
        .ev_low_o      (ev_temp_low),
        .rgb_r_o       (led4_r_o),
        .rgb_g_o       (led4_g_o),
        .rgb_b_o       (led4_b_o)
    );

    // ---- Bluetooth: messages out ---------------------------------------------
    // The texts can be changed here without touching any logic (max 16 chars).
    bt_msg_tx #(
        .CLKS_PER_BIT (UART_CLKS_PER_BIT),
        .MSG0 ("FALL"),
        .MSG1 ("SOS"),
        .MSG2 ("OK"),
        .MSG3 ("TEMP HIGH"),
        .MSG4 ("TEMP LOW"),
        .MSG5 ("SET"),
        .MSG6 ("ARE YOU OK?"),
        .MSG7 ("")
    ) u_bt_msg (
        .clk_i   (sysclk_i),
        .rst_n_i (rst_n),
        .req_i   ({1'b0, ev_ask, cfg_update, ev_temp_low, ev_temp_high, ev_ok, ev_sos, ev_fall}),
        .tx_o    (bt_tx_o),
        .busy_o  ()
    );

    // ---- Indicators -------------------------------------------------------------
    assign led_o[0] = beat;
    assign led_o[1] = accel_ok;
    assign led_o[2] = (sys_state == 2'd1) & blink_cnt_r[24];
    assign led_o[3] = (sys_state == 2'd2);
    assign led5_b_o = (fall_state != 3'd0) & blink_cnt_r[12];   // dimmed

    // ---- ILA: recording for the fall experiments (scripts/capture.tcl) --------
    // The ILA stores one point per sample (when accel_valid = 1), so the
    // one-cycle fall pulse is held until the next sample has been stored.
    reg fall_flag_r = 1'b0;
    always @(posedge sysclk_i) begin
        if (!rst_n)           fall_flag_r <= 1'b0;
        else if (fall_pulse)  fall_flag_r <= 1'b1;
        else if (accel_valid) fall_flag_r <= 1'b0;
    end

    ila_accel u_ila (
        .clk    (sysclk_i),
        .probe0 (accel_valid),
        .probe1 (accel_x),
        .probe2 (accel_y),
        .probe3 (accel_z),
        .probe4 (mag_sq),
        .probe5 (fall_state),
        .probe6 (sys_state),
        .probe7 (fall_flag_r)
    );

endmodule
