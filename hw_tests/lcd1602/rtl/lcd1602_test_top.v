// -----------------------------------------------------------------------------
// Module : lcd1602_test_top
// Owner  : integrator (hardware compatibility test, not part of guardian_top)
// Purpose: Stand-alone test of a 1602A character LCD (HD44780, 4-bit mode,
//          write-only) on a PYNQ-Z2.
//          - Initializes the LCD, loads two custom characters (heart, smiley)
//            into CGRAM, then redraws both lines continuously.
//          - sw_i[0] = 0 : page 0  "PYNQ-Z2 + 1602A "
//                                  "<heart> OK <smiley>  T=0000s  "
//            sw_i[0] = 1 : page 1  "Are you OK?   <heart><smiley>"
//                                  "Cancel in: 10 s "  (counts 10 -> 0)
//          - btn_i[0]   : restart (re-initialize LCD, clear counters)
//          - led_o[0] = first full draw finished, led_o[1] = heartbeat
//            (toggles every second), led_o[2] = page, led_o[3] = restart
//            button pressed
// Clock  : sysclk_i 125 MHz
// Reset  : btn_i[0], synchronized, active high at the pin
// -----------------------------------------------------------------------------
module lcd1602_test_top #(
    parameter PWR_CYC   = 12_500_000,     // 100 ms power-on wait
    parameter INIT_CYC  = 625_000,        // 5 ms after each init step
    parameter WAIT_CYC  = 250_000,        // 2 ms after each normal byte
    parameter PHASE_CYC = 1250,           // 10 us E setup / high / hold
    parameter SEC_CYC   = 125_000_000     // 1 s
) (
    input  wire       sysclk_i,
    input  wire [3:0] btn_i,
    input  wire [1:0] sw_i,
    output wire [3:0] led_o,
    output wire       lcd_rs_o,
    output wire       lcd_e_o,
    output wire [3:0] lcd_d_o
);
    // ---------------- input synchronizers ----------------
    reg [1:0] btn0_ff = 2'b00;
    reg [1:0] sw0_ff  = 2'b00;
    always @(posedge sysclk_i) begin
        btn0_ff <= {btn0_ff[0], btn_i[0]};
        sw0_ff  <= {sw0_ff[0],  sw_i[0]};
    end
    wire rst_n = ~btn0_ff[1];
    wire page  = sw0_ff[1];

    // ---------------- 1 s tick, counters ----------------
    reg [27:0] sec_cnt = 28'd0;
    reg        hb      = 1'b0;
    reg [3:0]  d0 = 4'd0;                 // BCD seconds, ones
    reg [3:0]  d1 = 4'd0;
    reg [3:0]  d2 = 4'd0;
    reg [3:0]  d3 = 4'd0;
    reg [3:0]  cd = 4'd10;                // countdown 10..0
    always @(posedge sysclk_i) begin
        if (!rst_n) begin
            sec_cnt <= 28'd0;
            hb <= 1'b0;
            d0 <= 4'd0; d1 <= 4'd0; d2 <= 4'd0; d3 <= 4'd0;
            cd <= 4'd10;
        end else if (sec_cnt == SEC_CYC - 1) begin
            sec_cnt <= 28'd0;
            hb <= ~hb;
            cd <= (cd == 4'd0) ? 4'd10 : cd - 4'd1;
            if (d0 == 4'd9) begin
                d0 <= 4'd0;
                if (d1 == 4'd9) begin
                    d1 <= 4'd0;
                    if (d2 == 4'd9) begin
                        d2 <= 4'd0;
                        d3 <= (d3 == 4'd9) ? 4'd0 : d3 + 4'd1;
                    end else begin
                        d2 <= d2 + 4'd1;
                    end
                end else begin
                    d1 <= d1 + 4'd1;
                end
            end else begin
                d0 <= d0 + 4'd1;
            end
        end else begin
            sec_cnt <= sec_cnt + 28'd1;
        end
    end

    // ---------------- screen content ----------------
    localparam [127:0] P0_L0 = "PYNQ-Z2 + 1602A ";
    localparam [127:0] P0_L1 = "  OK    T=0000s ";   // cols 0,5,10..13 replaced
    localparam [127:0] P1_L0 = "Are you OK?     ";   // cols 14,15 replaced
    localparam [127:0] P1_L1 = "Cancel in: 00 s ";   // cols 11,12 replaced

    function [7:0] str_at;
        input [127:0] s;
        input [3:0]   col;
        begin
            str_at = s[8*(15-col) +: 8];
        end
    endfunction

    function [7:0] char_at;
        input       pg;
        input       line;
        input [3:0] col;
        begin
            case ({pg, line})
                2'b00: char_at = str_at(P0_L0, col);
                2'b01: begin
                    case (col)
                        4'd0:    char_at = 8'h00;              // heart
                        4'd5:    char_at = 8'h01;              // smiley
                        4'd10:   char_at = {4'h3, d3};
                        4'd11:   char_at = {4'h3, d2};
                        4'd12:   char_at = {4'h3, d1};
                        4'd13:   char_at = {4'h3, d0};
                        default: char_at = str_at(P0_L1, col);
                    endcase
                end
                2'b10: begin
                    case (col)
                        4'd14:   char_at = 8'h00;
                        4'd15:   char_at = 8'h01;
                        default: char_at = str_at(P1_L0, col);
                    endcase
                end
                default: begin
                    case (col)
                        4'd11:   char_at = (cd == 4'd10) ? 8'h31 : 8'h20;
                        4'd12:   char_at = (cd == 4'd10) ? 8'h30 : {4'h3, cd};
                        default: char_at = str_at(P1_L1, col);
                    endcase
                end
            endcase
        end
    endfunction

    // custom characters, 5x8 dots: char 0 = heart, char 1 = smiley
    function [7:0] cgram_at;
        input [3:0] i;
        begin
            case (i)
                4'd0:    cgram_at = 8'b00000;
                4'd1:    cgram_at = 8'b01010;
                4'd2:    cgram_at = 8'b11111;
                4'd3:    cgram_at = 8'b11111;
                4'd4:    cgram_at = 8'b11111;
                4'd5:    cgram_at = 8'b01110;
                4'd6:    cgram_at = 8'b00100;
                4'd7:    cgram_at = 8'b00000;
                4'd8:    cgram_at = 8'b00000;
                4'd9:    cgram_at = 8'b01010;
                4'd10:   cgram_at = 8'b01010;
                4'd11:   cgram_at = 8'b00000;
                4'd12:   cgram_at = 8'b10001;
                4'd13:   cgram_at = 8'b01110;
                4'd14:   cgram_at = 8'b00000;
                default: cgram_at = 8'b00000;
            endcase
        end
    endfunction

    // ---------------- sequence table ----------------
    // idx 0..3   : 4-bit entry sequence (nibbles 3,3,3,2)
    // idx 4..7   : function set, display on, clear, entry mode
    // idx 8      : set CGRAM address 0
    // idx 9..24  : 16 CGRAM bytes
    // idx 25     : set DDRAM address 0x00 (line 1)
    // idx 26..41 : line 1
    // idx 42     : set DDRAM address 0x40 (line 2)
    // idx 43..58 : line 2, then back to idx 25
    localparam IDX_LAST    = 6'd58;
    localparam IDX_REFRESH = 6'd25;

    reg  [5:0] idx = 6'd0;
    reg        item_rs;
    reg        item_nib;
    reg  [7:0] item_data;
    wire [5:0] i_cg = idx - 6'd9;
    wire [5:0] i_l0 = idx - 6'd26;
    wire [5:0] i_l1 = idx - 6'd43;

    always @(*) begin
        item_rs   = 1'b0;
        item_nib  = 1'b0;
        item_data = 8'h00;
        if (idx <= 6'd2) begin
            item_nib  = 1'b1;
            item_data = 8'h30;
        end else if (idx == 6'd3) begin
            item_nib  = 1'b1;
            item_data = 8'h20;
        end else if (idx == 6'd4) begin
            item_data = 8'h28;                 // 4-bit, 2 lines, 5x8 font
        end else if (idx == 6'd5) begin
            item_data = 8'h0C;                 // display on, cursor off
        end else if (idx == 6'd6) begin
            item_data = 8'h01;                 // clear display
        end else if (idx == 6'd7) begin
            item_data = 8'h06;                 // entry mode: increment
        end else if (idx == 6'd8) begin
            item_data = 8'h40;                 // CGRAM address 0
        end else if (idx <= 6'd24) begin
            item_rs   = 1'b1;
            item_data = cgram_at(i_cg[3:0]);
        end else if (idx == 6'd25) begin
            item_data = 8'h80;                 // DDRAM address 0x00
        end else if (idx <= 6'd41) begin
            item_rs   = 1'b1;
            item_data = char_at(page, 1'b0, i_l0[3:0]);
        end else if (idx == 6'd42) begin
            item_data = 8'hC0;                 // DDRAM address 0x40
        end else begin
            item_rs   = 1'b1;
            item_data = char_at(page, 1'b1, i_l1[3:0]);
        end
    end

    wire [23:0] item_wait = (idx <= 6'd7) ? INIT_CYC : WAIT_CYC;

    // ---------------- main FSM ----------------
    localparam M_PWR  = 2'd0,
               M_SEND = 2'd1,
               M_BUSY = 2'd2;

    reg [1:0]  mstate    = M_PWR;
    reg [23:0] pwr_cnt   = 24'd0;
    reg        start     = 1'b0;
    reg        init_done = 1'b0;
    wire       drv_busy;
    wire       drv_done;

    always @(posedge sysclk_i) begin
        start <= 1'b0;
        if (!rst_n) begin
            mstate    <= M_PWR;
            pwr_cnt   <= 24'd0;
            idx       <= 6'd0;
            init_done <= 1'b0;
        end else begin
            case (mstate)
                M_PWR: begin
                    if (pwr_cnt == PWR_CYC - 1) begin
                        mstate <= M_SEND;
                    end else begin
                        pwr_cnt <= pwr_cnt + 24'd1;
                    end
                end
                M_SEND: begin
                    start  <= 1'b1;
                    mstate <= M_BUSY;
                end
                M_BUSY: begin
                    if (drv_done) begin
                        if (idx == IDX_LAST) begin
                            idx       <= IDX_REFRESH;
                            init_done <= 1'b1;
                        end else begin
                            idx <= idx + 6'd1;
                        end
                        mstate <= M_SEND;
                    end
                end
                default: mstate <= M_PWR;
            endcase
        end
    end

    lcd1602_driver #(.PHASE_CYC(PHASE_CYC)) u_drv (
        .clk_i      (sysclk_i),
        .rst_n_i    (rst_n),
        .start_i    (start),
        .rs_i       (item_rs),
        .data_i     (item_data),
        .nib_only_i (item_nib),
        .wait_cyc_i (item_wait),
        .busy_o     (drv_busy),
        .done_o     (drv_done),
        .lcd_rs_o   (lcd_rs_o),
        .lcd_e_o    (lcd_e_o),
        .lcd_d_o    (lcd_d_o)
    );

    assign led_o = {btn0_ff[1], page, hb, init_done};
endmodule
