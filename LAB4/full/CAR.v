`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name : CAR  (Lab 4 - Bluetooth remote-controlled car, FULL version)
//               basic 80 + A1 spin / reverse turns + C1 over-temperature alarm
// Board       : PYNQ-Z2 (xc7z020clg400-1), CLK = 125 MHz (H16)
// Based on    : teacher's 1116 reference CAR.v (same ports, pins, TMP3 I2C and
//               temperature TX blocks are kept unchanged)
//
// Changes vs. the reference (all for robustness of the basic 80-point function):
//   1. RX input goes through a 2-FF synchronizer; RX block uses non-blocking
//      assignments and produces a one-clock RX_DONE strobe (stop bit checked).
//   2. The motor outputs ar[13:10] come from a REGISTERED command (MOTOR) that is
//      updated only when a complete, valid command byte is received.
//      -> CR / LF / any unknown character no longer stops the car
//         (the reference decoded SBUF directly, so "W" + CR LF from a phone
//          terminal app would immediately fall into "default" = 0000).
//   3. Lower-case commands are accepted too (w/a/s/d/q).
//   4. The 4 LEDs show the current motion: LD0 forward, LD1 back, LD2 left,
//      LD3 right, all off = stop.
//   5. All registers have initial values (clean simulation, defined power-up).
//
// Motor interface (Arduino-car PortB[5:2] = ar[13:10]):
//   ar[10] = PB2 left  wheel enable     ar[12] = PB4 left  wheel dir (1 = fwd)
//   ar[11] = PB3 right wheel enable     ar[13] = PB5 right wheel dir (1 = fwd)
//   ar[13:10] = 1100 Stop     (Q = 51H)
//   ar[13:10] = 1111 Forward  (W = 57H)
//   ar[13:10] = 0011 Back     (S = 53H)
//   ar[13:10] = 1101 Right    (D = 44H)  left wheel runs, right wheel stops
//   ar[13:10] = 1110 Left     (A = 41H)  right wheel runs, left wheel stops
//   ar[13:10] = 0000 Power-on (motors off)
//  Extended motions (bonus A1):
//   ar[13:10] = 1011 Spin left     (Z = 5AH)  left wheel back,  right wheel fwd
//   ar[13:10] = 0111 Spin right    (X = 58H)  left wheel fwd,   right wheel back
//   ar[13:10] = 0010 Reverse-left  (C = 43H)  only right wheel back (rear swings left)
//   ar[13:10] = 0001 Reverse-right (V = 56H)  only left wheel back  (rear swings right)
//
// Over-temperature alarm (bonus C1):
//   HOT is set when the TMP3 temperature >= TH_HOT and cleared when it drops
//   to <= TH_COOL (hysteresis, no flicker). While HOT:
//     - both RGB LEDs blink red (~3.7 Hz), the 4 LEDs blink together
//     - a '!' is sent after the two temperature digits on Bluetooth
//   Driving still works normally during the alarm.
//////////////////////////////////////////////////////////////////////////////////

module CAR(CLK, led, led4, led5, JA, JAIN, JB, JBIN, ar);

    parameter FCLK  = 125000000;            // PIN:H16 Clock = 125 MHz
    parameter FBAUD = 9600;                 // Bluetooth baud rate = 9600
    parameter TBAUD = (FCLK/FBAUD)/2 - 1;   // TBAUD = 6509 (half bit time)

    parameter FI2C  = 200000;               // TMP3 SCL timing base = 200 kHz
    parameter TI2C  = (FCLK/FI2C)/2 - 1;    // TI2C = 311

    // RX sample points (clock cycles after the start-bit falling edge)
    // 1 bit = 13020.8 cycles; bit n is sampled at (1.5 + n) bit times
    parameter RX_B0   = 19531;
    parameter RX_BIT  = 13021;
    parameter RX_END  = 123699;             // middle of the stop bit

    // Over-temperature thresholds (deg C)
    parameter TH_HOT  = 8'd30;              // alarm on  at >= 30 C
    parameter TH_COOL = 8'd28;              // alarm off at <= 28 C

    input  CLK;
    output [13:10] ar;
    output [3:0] led;
    output [2:0] led4;
    output [2:0] led5;
    output [2:0] JA;    // JA[2]=TX (Y16), JA[0]=TX baud observe (Y18), JA[1] unused (Y19)
    input  JAIN;        // RX (Y17)
    output [2:0] JB;    // JB[2]=SCL (T11), JB[0]=I2C observe (W14), JB[1] unused (Y14)
    inout  JBIN;        // SDA (T10)

    wire [3:0] NUM, NUM2, NUM3;

    reg [35:0] DIV    = 36'd0;
    reg [3:0]  led    = 4'b0000;
    reg [2:0]  led4   = 3'b000;  // [r,g,b]
    reg [2:0]  led5   = 3'b000;  // [r,g,b]
    reg [2:0]  JA     = 3'b111;
    reg [2:0]  JB     = 3'b111;

// Bluetooth RX
    reg [1:0]  RX_SYNC = 2'b11;
    wire       RXD     = RX_SYNC[1];
    reg [7:0]  SBUF    = 8'h00;
    reg        RS      = 1'b0;
    reg [16:0] RXCT    = 17'd0;
    reg        RX_DONE = 1'b0;

// Car command
    reg [3:0]  MOTOR   = 4'b0000;   // drives ar[13:10]

// Bluetooth TX
    reg [14:0] BAUDT   = 15'd0;
    reg [13:0] CKBAUD  = 14'd0;

// I2C for TMP3
    wire JBIN;
    reg [13:0] I2CT    = 14'd0;
    reg [9:0]  CKI2C   = 10'd0;
    reg [8:0]  TBUF    = 9'd0;
    reg [3:0]  TMP0    = 4'd0;
    reg [3:0]  TMP1    = 4'd0;
    reg        SDA_OUT = 1'b1;

// Over-temperature alarm
    reg [7:0]  TEMP    = 8'd0;   // latched integer temperature (two's complement)
    reg        HOT     = 1'b0;
    wire       BLINK   = DIV[24];  // ~3.7 Hz

// Up counter
    always @(posedge CLK)
        DIV <= DIV + 1'b1;

    assign NUM  = DIV[27:24];
    assign NUM2 = DIV[31:28];
    assign NUM3 = DIV[35:32];

// Four LEDs: current motion (LD0 fwd, LD1 back, LD2 left, LD3 right),
//            all blinking together while the over-temperature alarm is on
    always @(posedge CLK)
        if (HOT)
            led <= {4{BLINK}};
        else
            case (MOTOR)
                4'b1111: led <= 4'b0001;  // forward
                4'b0011: led <= 4'b0010;  // back
                4'b1110: led <= 4'b0100;  // left
                4'b1101: led <= 4'b1000;  // right
                4'b1011: led <= 4'b0111;  // spin left     (LD0+LD1+LD2)
                4'b0111: led <= 4'b1011;  // spin right    (LD0+LD1+LD3)
                4'b0010: led <= 4'b0110;  // reverse-left  (LD1+LD2)
                4'b0001: led <= 4'b1010;  // reverse-right (LD1+LD3)
                default: led <= 4'b0000;  // stop / power-on
            endcase

// RGB LEDs: reference colour-cycling effect, red blinking while HOT
    always @(posedge CLK)
        led4 <= HOT ? {BLINK, 2'b00} : DIV[30:28];

    always @(posedge CLK)
        led5 <= HOT ? {BLINK, 2'b00} : DIV[33:31];

//---- Baud-rate tick generator, TBAUD = 6509, FBAUD = 9600
    always @(posedge CLK)
        begin
            if (CKBAUD < TBAUD)
                CKBAUD <= CKBAUD + 1;

            if (CKBAUD == TBAUD)
                begin
                    CKBAUD <= 0;
                    BAUDT  <= BAUDT + 1'b1;
                end
        end

    always @(posedge CLK)
        JA[0] <= BAUDT[5];

//---- RS232 RX (8N1, 9600 baud)
    always @(posedge CLK)
        RX_SYNC <= {RX_SYNC[0], JAIN};

    always @(posedge CLK)
        begin
            RX_DONE <= 1'b0;
            if (RXD & !RS)
                RXCT <= 17'd0;                       // idle, wait for start bit
            else
                begin
                    RS   <= 1'b1;
                    RXCT <= RXCT + 1'b1;
                    case (RXCT)
                        RX_B0:            SBUF[0] <= RXD;
                        RX_B0 + 1*RX_BIT: SBUF[1] <= RXD;
                        RX_B0 + 2*RX_BIT: SBUF[2] <= RXD;
                        RX_B0 + 3*RX_BIT: SBUF[3] <= RXD;
                        RX_B0 + 4*RX_BIT: SBUF[4] <= RXD;
                        RX_B0 + 5*RX_BIT: SBUF[5] <= RXD;
                        RX_B0 + 6*RX_BIT: SBUF[6] <= RXD;
                        RX_B0 + 7*RX_BIT: SBUF[7] <= RXD;
                        RX_END:
                            begin
                                RS      <= 1'b0;
                                RX_DONE <= RXD;      // valid only if stop bit = 1
                            end
                        default: ;
                    endcase
                end
        end

//---- Command decoder: update the car only on a complete, valid command
    always @(posedge CLK)
        if (RX_DONE)
            case (SBUF)
                8'h51, 8'h71: MOTOR <= 4'b1100;  // Q / q : stop
                8'h57, 8'h77: MOTOR <= 4'b1111;  // W / w : forward
                8'h53, 8'h73: MOTOR <= 4'b0011;  // S / s : back
                8'h44, 8'h64: MOTOR <= 4'b1101;  // D / d : turn right
                8'h41, 8'h61: MOTOR <= 4'b1110;  // A / a : turn left
                8'h5A, 8'h7A: MOTOR <= 4'b1011;  // Z / z : spin left
                8'h58, 8'h78: MOTOR <= 4'b0111;  // X / x : spin right
                8'h43, 8'h63: MOTOR <= 4'b0010;  // C / c : reverse-left
                8'h56, 8'h76: MOTOR <= 4'b0001;  // V / v : reverse-right
                default:      MOTOR <= MOTOR;    // CR, LF, others: ignored
            endcase

    assign ar = MOTOR;

//---- RS232 TX: temperature as two ASCII digits (tens, ones) every ~1.7 s
//     (reference block; only slot 3 added: '!' = 21H when HOT)
    always @(posedge CLK)
        if (BAUDT[14:5] == 1)
            begin
                case (BAUDT[4:1])
                    4'b0000: JA[2] = 1'b0;
                    4'b0001: JA[2] = TMP1[0];
                    4'b0010: JA[2] = TMP1[1];
                    4'b0011: JA[2] = TMP1[2];
                    4'b0100: JA[2] = TMP1[3];
                    4'b0101: JA[2] = 1;
                    4'b0110: JA[2] = 1;
                    4'b0111: JA[2] = 0;
                    4'b1000: JA[2] = 0;
                    default: JA[2] = 1'b1;
                endcase
            end
        else if (BAUDT[14:5] == 2)
            begin
                case (BAUDT[4:1])
                    4'b0000: JA[2] = 1'b0;
                    4'b0001: JA[2] = TMP0[0];
                    4'b0010: JA[2] = TMP0[1];
                    4'b0011: JA[2] = TMP0[2];
                    4'b0100: JA[2] = TMP0[3];
                    4'b0101: JA[2] = 1;
                    4'b0110: JA[2] = 1;
                    4'b0111: JA[2] = 0;
                    4'b1000: JA[2] = 0;
                    default: JA[2] = 1'b1;
                endcase
            end
        else if ((BAUDT[14:5] == 3) && HOT)
            begin
                case (BAUDT[4:1])          // '!' = 0010_0001, LSB first
                    4'b0000: JA[2] = 1'b0; // start bit
                    4'b0001: JA[2] = 1;
                    4'b0010: JA[2] = 0;
                    4'b0011: JA[2] = 0;
                    4'b0100: JA[2] = 0;
                    4'b0101: JA[2] = 0;
                    4'b0110: JA[2] = 1;
                    4'b0111: JA[2] = 0;
                    4'b1000: JA[2] = 0;
                    default: JA[2] = 1'b1; // stop bit / idle
                endcase
            end
        else
            JA[2] = 1'b1;

//---- I2C timing base (reference block, unchanged)
    always @(posedge CLK)
        begin
            if (CKI2C < TI2C)
                CKI2C <= CKI2C + 1;

            if (CKI2C == TI2C)
                begin
                    CKI2C <= 0;
                    I2CT  <= I2CT + 1'b1;
                end
        end

//---- TMP3 read, address 0x48 (reference block, unchanged)
    assign JBIN = SDA_OUT ? 1'bz : 1'b0;
    always @(posedge CLK)
        if (I2CT == 0)
            begin
                SDA_OUT = 1'b0;    // START
                JB[0]   = 1'b0;    // observe
            end
        else if (I2CT < 60)
            begin
                JB[2] = I2CT[0];   // SCL
                case (I2CT[5:0])
                    6'b000010: SDA_OUT = 1'b1; // address 1001000
                    6'b000100: SDA_OUT = 1'b0;
                    6'b000110: SDA_OUT = 1'b0;
                    6'b001000: SDA_OUT = 1'b1;
                    6'b001010: SDA_OUT = 1'b0;
                    6'b001100: SDA_OUT = 1'b0;
                    6'b001110: SDA_OUT = 1'b0;
                    6'b010000: SDA_OUT = 1'b1; // R/W = 1 (read)
                    6'b010010: SDA_OUT = 1'b1; // release for slave ACK
                    6'b010100: TBUF[8] = JBIN; // temperature serial data
                    6'b010110: TBUF[7] = JBIN;
                    6'b011000: TBUF[6] = JBIN;
                    6'b011010: TBUF[5] = JBIN;
                    6'b011100: TBUF[4] = JBIN;
                    6'b011110: TBUF[3] = JBIN;
                    6'b100000: TBUF[2] = JBIN;
                    6'b100010: TBUF[1] = JBIN;
                    6'b100100: TBUF[0] = JBIN;
                endcase
            end
        else
            begin
                JB[2]   = 1'b1;
                JB[0]   = 1'b1;
                SDA_OUT = 1'b1;
                TMP1    = TBUF[8:1] / 10;
                TMP0    = TBUF[8:1] % 10;
            end

//---- Over-temperature alarm (bonus C1)
//     TEMP is latched after each I2C read is finished (TBUF changes bit by bit
//     during the read window I2CT < 60, so it must not be used directly).
    always @(posedge CLK)
        if (I2CT == 14'd100)
            TEMP <= TBUF[8:1];

    always @(posedge CLK)
        if (TEMP[7])                       // negative or no sensor (0xFF)
            HOT <= 1'b0;
        else if (TEMP >= TH_HOT)
            HOT <= 1'b1;
        else if (TEMP <= TH_COOL)
            HOT <= 1'b0;

endmodule
