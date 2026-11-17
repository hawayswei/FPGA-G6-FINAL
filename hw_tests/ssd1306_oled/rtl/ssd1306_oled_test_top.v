// -----------------------------------------------------------------------------
// Module : ssd1306_oled_test_top
// Owner  : integrator (hardware compatibility test, not part of guardian_top)
// Purpose: Stand-alone test of a 0.96" 128x64 I2C OLED (SSD1306, address 0x3C)
//          on a PYNQ-Z2.
//          - Waits 100 ms, clears the bus, sends the SSD1306 init sequence, then redraws the
//            whole screen (1024 bytes, horizontal addressing) continuously,
//            about 10 frames per second at 100 kHz.
//          - sw_i[0] = 0 : text page with a 1-pixel border
//                          "PYNQ-Z2 OLED OK", "SSD1306 128X64",
//                          "ADDR 0x3C 100kHz", "UPTIME 0000 s" (counts up),
//                          "SW0 TEXT/PATTERN", and a bar that grows each second
//            sw_i[0] = 1 : 8x8 checkerboard that inverts every second
//          - btn_i[0]   : restart (wait, re-init, clear counters)
//          - Any NACK aborts the transfer with a STOP, waits 100 ms and starts
//            again from the init sequence.
//          - led_o[0] = init sequence ACKed (display should be on)
//            led_o[1] = heartbeat (toggles every second)
//            led_o[2] = NACK error (no device answered; wiring / address)
//            led_o[3] = toggles after every full frame (data is streaming)
//          - SCL/SDA are open-drain: only 0 or Z is ever driven.
//          - Diagnostics (added after a first on-board NACK):
//            * auto scan: after each NACK the next of 4 settings is tried:
//              {pins normal / pins swapped} x {address 0x3C / 0x3D}; the
//              first setting whose address byte is ACKed is kept
//            * sw_i[1] = 1 : ignore NACK, always use pins normal + 0x3C and
//              stream anyway (for modules that never pull the ACK low)
//            * RGB LD4 = line level while the bus is released:
//              green = both high (pull-ups present), red = P16 (SCL) stuck
//              low, blue = P15 (SDA) stuck low
//            * RGB LD5 = setting that got an ACK: green = normal 0x3C,
//              blue = normal 0x3D, yellow = swapped 0x3C, magenta = swapped
//              0x3D, off = nothing answered yet
// Clock  : sysclk_i 125 MHz
// Reset  : btn_i[0], synchronized, active high at the pin
// -----------------------------------------------------------------------------
module ssd1306_oled_test_top #(
    parameter [6:0] I2C_ADDR  = 7'h3C,        // 0x78 >> 1 on the silkscreen
    parameter       QTR_CYC   = 313,          // 1/4 SCL period: 99.8 kHz
    parameter       PWR_CYC   = 12_500_000,   // 100 ms power-on wait
    parameter       RETRY_CYC = 12_500_000,   // 100 ms wait after a NACK
    parameter       SEC_CYC   = 125_000_000   // 1 s
) (
    input  wire       sysclk_i,
    input  wire [3:0] btn_i,
    input  wire [1:0] sw_i,
    output wire [3:0] led_o,
    output wire       led4_r_o,
    output wire       led4_g_o,
    output wire       led4_b_o,
    output wire       led5_r_o,
    output wire       led5_g_o,
    output wire       led5_b_o,
    inout  wire       oled_scl_io,      // P16, header SCL
    inout  wire       oled_sda_io       // P15, header SDA
);
    // ---------------- input synchronizers ----------------
    reg [1:0] btn0_ff = 2'b00;
    reg [1:0] sw0_ff  = 2'b00;
    reg [1:0] sw1_ff  = 2'b00;
    reg [1:0] p16_ff  = 2'b11;
    reg [1:0] p15_ff  = 2'b11;
    always @(posedge sysclk_i) begin
        btn0_ff <= {btn0_ff[0], btn_i[0]};
        sw0_ff  <= {sw0_ff[0],  sw_i[0]};
        sw1_ff  <= {sw1_ff[0],  sw_i[1]};
        p16_ff  <= {p16_ff[0],  oled_scl_io};
        p15_ff  <= {p15_ff[0],  oled_sda_io};
    end
    wire rst_n    = ~btn0_ff[1];
    wire page     = sw0_ff[1];
    wire ign_nack = sw1_ff[1];

    // diagnostic scan state: combo[1] = pins swapped, combo[0] = address 0x3D
    reg  [1:0] combo = 2'b00;
    reg        found = 1'b0;
    wire [1:0] cfg   = ign_nack ? 2'b00 : combo;

    // ---------------- 1 s tick, BCD uptime ----------------
    reg [27:0] sec_cnt = 28'd0;
    reg        hb = 1'b0;
    reg [3:0]  d0 = 4'd0;
    reg [3:0]  d1 = 4'd0;
    reg [3:0]  d2 = 4'd0;
    reg [3:0]  d3 = 4'd0;
    always @(posedge sysclk_i) begin
        if (!rst_n) begin
            sec_cnt <= 28'd0;
            hb <= 1'b0;
            d0 <= 4'd0; d1 <= 4'd0; d2 <= 4'd0; d3 <= 4'd0;
        end else if (sec_cnt == SEC_CYC - 1) begin
            sec_cnt <= 28'd0;
            hb <= ~hb;
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

    // values frozen for one frame (no tearing inside a frame)
    reg       pg_q = 1'b0;
    reg       hb_q = 1'b0;
    reg [3:0] s_d0 = 4'd0;
    reg [3:0] s_d1 = 4'd0;
    reg [3:0] s_d2 = 4'd0;
    reg [3:0] s_d3 = 4'd0;

    // ---------------- 5x7 font, ASCII 0x20..0x5F + x k s z ----------------
    // 5 column bytes, first column in bits [39:32], bit 0 = top row
    function [39:0] font5;
        input [7:0] ch;
        begin
            case (ch)
                8'h20: font5 = 40'h00_00_00_00_00;
                8'h21: font5 = 40'h00_00_5F_00_00;
                8'h22: font5 = 40'h00_07_00_07_00;
                8'h23: font5 = 40'h14_7F_14_7F_14;
                8'h24: font5 = 40'h24_2A_7F_2A_12;
                8'h25: font5 = 40'h23_13_08_64_62;
                8'h26: font5 = 40'h36_49_56_20_50;
                8'h27: font5 = 40'h00_05_03_00_00;
                8'h28: font5 = 40'h00_1C_22_41_00;
                8'h29: font5 = 40'h00_41_22_1C_00;
                8'h2A: font5 = 40'h2A_1C_7F_1C_2A;
                8'h2B: font5 = 40'h08_08_3E_08_08;
                8'h2C: font5 = 40'h00_50_30_00_00;
                8'h2D: font5 = 40'h08_08_08_08_08;
                8'h2E: font5 = 40'h00_60_60_00_00;
                8'h2F: font5 = 40'h20_10_08_04_02;
                8'h30: font5 = 40'h3E_51_49_45_3E;
                8'h31: font5 = 40'h00_42_7F_40_00;
                8'h32: font5 = 40'h42_61_51_49_46;
                8'h33: font5 = 40'h21_41_45_4B_31;
                8'h34: font5 = 40'h18_14_12_7F_10;
                8'h35: font5 = 40'h27_45_45_45_39;
                8'h36: font5 = 40'h3C_4A_49_49_30;
                8'h37: font5 = 40'h01_71_09_05_03;
                8'h38: font5 = 40'h36_49_49_49_36;
                8'h39: font5 = 40'h06_49_49_29_1E;
                8'h3A: font5 = 40'h00_36_36_00_00;
                8'h3B: font5 = 40'h00_56_36_00_00;
                8'h3C: font5 = 40'h08_14_22_41_00;
                8'h3D: font5 = 40'h14_14_14_14_14;
                8'h3E: font5 = 40'h00_41_22_14_08;
                8'h3F: font5 = 40'h02_01_51_09_06;
                8'h40: font5 = 40'h32_49_79_41_3E;
                8'h41: font5 = 40'h7E_11_11_11_7E;
                8'h42: font5 = 40'h7F_49_49_49_36;
                8'h43: font5 = 40'h3E_41_41_41_22;
                8'h44: font5 = 40'h7F_41_41_22_1C;
                8'h45: font5 = 40'h7F_49_49_49_41;
                8'h46: font5 = 40'h7F_09_09_09_01;
                8'h47: font5 = 40'h3E_41_49_49_7A;
                8'h48: font5 = 40'h7F_08_08_08_7F;
                8'h49: font5 = 40'h00_41_7F_41_00;
                8'h4A: font5 = 40'h20_40_41_3F_01;
                8'h4B: font5 = 40'h7F_08_14_22_41;
                8'h4C: font5 = 40'h7F_40_40_40_40;
                8'h4D: font5 = 40'h7F_02_0C_02_7F;
                8'h4E: font5 = 40'h7F_04_08_10_7F;
                8'h4F: font5 = 40'h3E_41_41_41_3E;
                8'h50: font5 = 40'h7F_09_09_09_06;
                8'h51: font5 = 40'h3E_41_51_21_5E;
                8'h52: font5 = 40'h7F_09_19_29_46;
                8'h53: font5 = 40'h46_49_49_49_31;
                8'h54: font5 = 40'h01_01_7F_01_01;
                8'h55: font5 = 40'h3F_40_40_40_3F;
                8'h56: font5 = 40'h1F_20_40_20_1F;
                8'h57: font5 = 40'h3F_40_38_40_3F;
                8'h58: font5 = 40'h63_14_08_14_63;
                8'h59: font5 = 40'h07_08_70_08_07;
                8'h5A: font5 = 40'h61_51_49_45_43;
                8'h5B: font5 = 40'h00_7F_41_41_00;
                8'h5C: font5 = 40'h02_04_08_10_20;
                8'h5D: font5 = 40'h00_41_41_7F_00;
                8'h5E: font5 = 40'h04_02_01_02_04;
                8'h5F: font5 = 40'h40_40_40_40_40;
                8'h6B: font5 = 40'h7F_10_28_44_00;   // k
                8'h73: font5 = 40'h48_54_54_54_20;   // s
                8'h78: font5 = 40'h44_28_10_28_44;   // x
                8'h7A: font5 = 40'h44_64_54_4C_44;   // z
                default: font5 = 40'h7F_41_41_41_7F; // box = unsupported
            endcase
        end
    endfunction

    // ---------------- text page ----------------
    // 20 characters per line, 6 pixels each, starting at column 4
    localparam [159:0] L1 = " PYNQ-Z2 OLED OK    ";
    localparam [159:0] L2 = " SSD1306 128X64     ";
    localparam [159:0] L3 = " ADDR 0x3C 100kHz   ";
    localparam [159:0] L4 = " UPTIME  0000 s     ";   // cx 9..12 replaced
    localparam [159:0] L5 = " SW0 TEXT/PATTERN   ";

    function [7:0] str_at;
        input [159:0] s;
        input [4:0]   cx;
        begin
            str_at = s[8*(19-cx) +: 8];
        end
    endfunction

    function [7:0] text_char;
        input [2:0] pg;
        input [4:0] cx;
        begin
            case (pg)
                3'd1: text_char = str_at(L1, cx);
                3'd2: text_char = str_at(L2, cx);
                3'd3: text_char = str_at(L3, cx);
                3'd4: begin
                    case (cx)
                        5'd9:    text_char = {4'h3, s_d3};
                        5'd10:   text_char = {4'h3, s_d2};
                        5'd11:   text_char = {4'h3, s_d1};
                        5'd12:   text_char = {4'h3, s_d0};
                        default: text_char = str_at(L4, cx);
                    endcase
                end
                3'd5:    text_char = str_at(L5, cx);
                default: text_char = 8'h20;
            endcase
        end
    endfunction

    // ---------------- sequence table ----------------
    // idx 0        : bus clear: 9 SCL pulses with SDA released, then STOP
    //                (frees an OLED left mid-byte by btn0; NACK ignored)
    // idx 1        : START + address (write)
    // idx 2        : control 0x00 (command stream)
    // idx 3..28    : 26 init commands, STOP after idx 28
    // idx 29..36   : START, addr, 0x00, 0x21 0 127, 0x22 0 7, STOP
    // idx 37, 38   : START, addr, control 0x40 (data stream)
    // idx 39..1062 : 1024 pixel bytes, STOP after the last, back to idx 29
    localparam [10:0] IDX_INIT_END = 11'd28;
    localparam [10:0] IDX_FRAME    = 11'd29;
    localparam [10:0] IDX_DATA_HDR = 11'd38;
    localparam [10:0] IDX_DATA     = 11'd39;
    localparam [10:0] IDX_LAST     = 11'd1062;
    wire [7:0]        ADDR_W       = {I2C_ADDR ^ {6'd0, cfg[0]}, 1'b0};

    function [7:0] init_cmd;
        input [4:0] i;
        begin
            case (i)
                5'd0:  init_cmd = 8'hAE;   // display off
                5'd1:  init_cmd = 8'hD5;   // clock divide / oscillator
                5'd2:  init_cmd = 8'h80;
                5'd3:  init_cmd = 8'hA8;   // multiplex ratio
                5'd4:  init_cmd = 8'h3F;   // 64 rows
                5'd5:  init_cmd = 8'hD3;   // display offset
                5'd6:  init_cmd = 8'h00;
                5'd7:  init_cmd = 8'h40;   // start line 0
                5'd8:  init_cmd = 8'h8D;   // charge pump
                5'd9:  init_cmd = 8'h14;   // enable (no external VCC)
                5'd10: init_cmd = 8'h20;   // memory addressing mode
                5'd11: init_cmd = 8'h00;   // horizontal
                5'd12: init_cmd = 8'hA1;   // segment remap (col 127 = SEG0)
                5'd13: init_cmd = 8'hC8;   // COM scan direction remapped
                5'd14: init_cmd = 8'hDA;   // COM pins configuration
                5'd15: init_cmd = 8'h12;   // alternative, for 128x64
                5'd16: init_cmd = 8'h81;   // contrast
                5'd17: init_cmd = 8'hCF;
                5'd18: init_cmd = 8'hD9;   // pre-charge period
                5'd19: init_cmd = 8'hF1;
                5'd20: init_cmd = 8'hDB;   // VCOMH deselect level
                5'd21: init_cmd = 8'h40;
                5'd22: init_cmd = 8'hA4;   // display follows RAM
                5'd23: init_cmd = 8'hA6;   // normal (not inverted)
                5'd24: init_cmd = 8'h2E;   // scrolling off
                default: init_cmd = 8'hAF; // display on
            endcase
        end
    endfunction

    reg  [10:0] idx = 11'd0;
    wire [10:0] i_init = idx - 11'd3;
    wire [10:0] di     = idx - IDX_DATA;

    // ---------------- pixel pipeline ----------------
    // idx is stable for about 1000 clocks per byte, so the pixel byte is
    // computed in registered stages; the FSM waits SETTLE_CYC clocks after
    // every idx change before it starts the I2C byte.
    // S1: page / column / x in text area
    reg [2:0]  pg1 = 3'd0;
    reg [6:0]  col1 = 7'd0;
    reg [6:0]  tx1 = 7'd0;
    // S2: character index cx = tx / 6
    reg [2:0]  pg2 = 3'd0;
    reg [6:0]  col2 = 7'd0;
    reg [6:0]  tx2 = 7'd0;
    reg [4:0]  cx2 = 5'd0;
    // S3: column inside the character cc = tx % 6, character code
    reg [2:0]  pg3 = 3'd0;
    reg [6:0]  col3 = 7'd0;
    reg [2:0]  cc3 = 3'd0;
    reg [7:0]  ch3 = 8'h20;
    // S4: pixel byte; S5: byte / START / STOP for the I2C master
    reg [7:0]  pix4 = 8'h00;

    wire [12:0] tx43    = tx1 * 6'd43;
    wire [6:0]  cx6     = cx2 * 3'd6;
    wire [6:0]  bar_end = 7'd4 + {s_d0, 3'b000} + {s_d0, 2'b00} + 7'd12;

    always @(posedge sysclk_i) begin
        pg1  <= di[9:7];
        col1 <= di[6:0];
        tx1  <= di[6:0] - 7'd4;
        pg2  <= pg1;
        col2 <= col1;
        tx2  <= tx1;
        cx2  <= tx43[12:8];                    // tx / 6, valid for tx < 126
        pg3  <= pg2;
        col3 <= col2;
        cc3  <= tx2 - cx6;
        ch3  <= text_char(pg2, cx2);
    end

    reg [39:0] glyph;
    reg [7:0]  text_byte;
    reg [7:0]  pix_byte;
    always @(*) begin
        glyph = font5(ch3);
        if (col3 == 7'd0 || col3 == 7'd127) begin
            text_byte = 8'hFF;
        end else begin
            if (col3 >= 7'd4 && col3 <= 7'd123 && pg3 >= 3'd1 && pg3 <= 3'd5)
                text_byte = (cc3 == 3'd5) ? 8'h00 : glyph[8*(4-cc3) +: 8];
            else if (pg3 == 3'd6 && col3 >= 7'd4 && col3 < bar_end)
                text_byte = 8'h3C;
            else
                text_byte = 8'h00;
            if (pg3 == 3'd0) text_byte = text_byte | 8'h01;
            if (pg3 == 3'd7) text_byte = text_byte | 8'h80;
        end
        if (pg_q)
            pix_byte = (pg3[0] ^ col3[3] ^ hb_q) ? 8'hFF : 8'h00;
        else
            pix_byte = text_byte;
    end

    always @(posedge sysclk_i) pix4 <= pix_byte;

    reg       item_start;
    reg       item_stop;
    reg [7:0] item_byte;
    always @(*) begin
        item_start = 1'b0;
        item_stop  = 1'b0;
        case (idx)
            11'd0:  begin item_stop = 1'b1; item_byte = 8'hFF; end
            11'd1:  begin item_start = 1'b1; item_byte = ADDR_W; end
            11'd2:  item_byte = 8'h00;
            11'd29: begin item_start = 1'b1; item_byte = ADDR_W; end
            11'd30: item_byte = 8'h00;
            11'd31: item_byte = 8'h21;                 // column range
            11'd32: item_byte = 8'h00;
            11'd33: item_byte = 8'h7F;
            11'd34: item_byte = 8'h22;                 // page range
            11'd35: item_byte = 8'h00;
            11'd36: begin item_stop = 1'b1; item_byte = 8'h07; end
            11'd37: begin item_start = 1'b1; item_byte = ADDR_W; end
            11'd38: item_byte = 8'h40;
            default: begin
                if (idx <= IDX_INIT_END) begin
                    item_byte = init_cmd(i_init[4:0]);
                    item_stop = (idx == IDX_INIT_END);
                end else begin
                    item_byte = pix4;
                    item_stop = (idx == IDX_LAST);
                end
            end
        endcase
    end

    reg       start_q = 1'b0;
    reg       stop_q  = 1'b0;
    reg [7:0] byte_q  = 8'h00;
    always @(posedge sysclk_i) begin
        start_q <= item_start;
        stop_q  <= item_stop;
        byte_q  <= item_byte;
    end

    // ---------------- main FSM ----------------
    localparam M_PWR   = 2'd0,
               M_SEND  = 2'd1,
               M_BUSY  = 2'd2,
               M_RETRY = 2'd3;

    localparam SETTLE_CYC = 24'd7;

    reg [1:0]  mstate    = M_PWR;
    reg [23:0] wait_cnt  = 24'd0;
    reg        send      = 1'b0;
    reg        init_done = 1'b0;
    reg        nack_flag = 1'b0;
    reg        frame_tog = 1'b0;
    reg        lvl16     = 1'b1;
    reg        lvl15     = 1'b1;
    wire       m_done;
    wire       m_nack;
    wire       m_busy;

    always @(posedge sysclk_i) begin
        send <= 1'b0;
        if (!rst_n) begin
            mstate    <= M_PWR;
            wait_cnt  <= 24'd0;
            idx       <= 11'd0;
            init_done <= 1'b0;
            nack_flag <= 1'b0;
            frame_tog <= 1'b0;
            combo     <= 2'b00;
            found     <= 1'b0;
        end else begin
            case (mstate)
                M_PWR: begin
                    if (wait_cnt == PWR_CYC - 1) begin
                        lvl16    <= p16_ff[1];         // bus released here
                        lvl15    <= p15_ff[1];
                        wait_cnt <= 24'd0;
                        mstate   <= M_SEND;
                    end else begin
                        wait_cnt <= wait_cnt + 24'd1;
                    end
                end
                M_SEND: begin                          // let the pipeline settle
                    if (wait_cnt == SETTLE_CYC && start_q &&
                        !(p16_ff[1] && p15_ff[1])) begin
                        // bus must be idle (both high) before a START; a
                        // line held low (unpowered module, short) would
                        // otherwise look like an ACK
                        lvl16     <= p16_ff[1];
                        lvl15     <= p15_ff[1];
                        wait_cnt  <= 24'd0;
                        nack_flag <= 1'b1;
                        init_done <= 1'b0;
                        idx       <= 11'd0;
                        mstate    <= M_RETRY;
                    end else if (wait_cnt == SETTLE_CYC) begin
                        if (start_q) begin
                            lvl16 <= p16_ff[1];
                            lvl15 <= p15_ff[1];
                        end
                        wait_cnt <= 24'd0;
                        send     <= 1'b1;
                        mstate   <= M_BUSY;
                    end else begin
                        wait_cnt <= wait_cnt + 24'd1;
                    end
                end
                M_BUSY: begin
                    if (m_done) begin
                        if (m_nack && idx != 11'd0 && !ign_nack) begin
                            nack_flag <= 1'b1;
                            init_done <= 1'b0;
                            idx       <= 11'd0;
                            mstate    <= M_RETRY;
                            if (!found) combo <= combo + 2'd1;
                        end else begin
                            if (m_nack && idx != 11'd0) nack_flag <= 1'b1;
                            if (idx == 11'd1 && !m_nack) begin
                                found     <= 1'b1;
                                combo     <= cfg;
                                nack_flag <= 1'b0;
                            end
                            if (idx == IDX_INIT_END) init_done <= 1'b1;
                            if (idx == IDX_DATA_HDR) begin
                                pg_q <= page;
                                hb_q <= hb;
                                s_d0 <= d0; s_d1 <= d1; s_d2 <= d2; s_d3 <= d3;
                            end
                            if (idx == IDX_LAST) begin
                                idx       <= IDX_FRAME;
                                frame_tog <= ~frame_tog;
                            end else begin
                                idx <= idx + 11'd1;
                            end
                            mstate <= M_SEND;
                        end
                    end
                end
                default: begin                         // M_RETRY
                    if (wait_cnt == RETRY_CYC - 1) begin
                        lvl16    <= p16_ff[1];
                        lvl15    <= p15_ff[1];
                        wait_cnt <= 24'd0;
                        mstate   <= M_SEND;
                    end else begin
                        wait_cnt <= wait_cnt + 24'd1;
                    end
                end
            endcase
        end
    end

    wire scl_low;
    wire sda_low;
    wire sda_in = cfg[1] ? oled_scl_io : oled_sda_io;

    ssd1306_i2c_master #(.QTR_CYC(QTR_CYC)) u_i2c (
        .clk_i     (sysclk_i),
        .rst_n_i   (rst_n),
        .send_i    (send),
        .start_i   (start_q),
        .stop_i    (stop_q),
        .data_i    (byte_q),
        .ign_nack_i(ign_nack),
        .sda_i     (sda_in),
        .busy_o    (m_busy),
        .done_o    (m_done),
        .nack_o    (m_nack),
        .scl_low_o (scl_low),
        .sda_low_o (sda_low)
    );

    // open-drain: drive 0 or release (Z); the pull-ups make the high level
    wire p16_low = cfg[1] ? sda_low : scl_low;
    wire p15_low = cfg[1] ? scl_low : sda_low;
    assign oled_scl_io = p16_low ? 1'b0 : 1'bz;
    assign oled_sda_io = p15_low ? 1'b0 : 1'bz;

    assign led_o = {frame_tog, nack_flag, hb, init_done};

    // RGB LEDs at 1/8 duty (full brightness is glaring)
    reg [2:0] dim = 3'd0;
    always @(posedge sysclk_i) dim <= dim + 3'd1;
    wire on = (dim == 3'd0);
    assign led4_r_o = on & ~lvl16;
    assign led4_b_o = on & ~lvl15;
    assign led4_g_o = on & lvl16 & lvl15;
    assign led5_r_o = on & found & cfg[1];
    assign led5_g_o = on & found & ~cfg[0];
    assign led5_b_o = on & found & cfg[0];
endmodule
