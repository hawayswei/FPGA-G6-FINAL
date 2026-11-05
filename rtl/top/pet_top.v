// ============================================================================
// Module : pet_top
// Owner  : integrator (only the integrator edits this file)
// Purpose: Top level of the desktop-pet project. Wires all subsystems
//          together. Currently a smoke-test skeleton only.
// Clock  : sysclk_i = 125 MHz (PYNQ-Z2 pin H16). All logic uses this clock.
//          Slower rates must use clock enables, not derived clocks.
//          Exceptions (camera pixel clock, HDMI pixel clock) must come from a
//          Clock Wizard IP and be documented in that subsystem's README.
// Reset  : One synchronous, active-low rst_n made by ctrl_reset_sync from
//          button btn_i[3]. Every module receives rst_n.
// ============================================================================
`timescale 1ns / 1ps

module pet_top (
    input  wire       sysclk_i,   // 125 MHz board clock
    input  wire [3:0] btn_i,      // push buttons, 1 = pressed
    output wire [3:0] led_o       // user LEDs
);

    wire rst_n;
    wire beat;

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

    // led_o[0] = heartbeat, led_o[1] = rst_n state,
    // led_o[3:2] echo buttons 2..1 (quick wiring check)
    assign led_o = {btn_i[2:1], rst_n, beat};

endmodule
