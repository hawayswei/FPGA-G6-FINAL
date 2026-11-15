`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name : CAR  (Lab 4 - Bluetooth remote-controlled car, BASIC version)
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

// Up counter
    always @(posedge CLK)
        DIV <= DIV + 1'b1;

    assign NUM  = DIV[27:24];
    assign NUM2 = DIV[31:28];
    assign NUM3 = DIV[35:32];

// Four LEDs: current motion (LD0 fwd, LD1 back, LD2 left, LD3 right)
    always @(posedge CLK)
        case (MOTOR)
            4'b1111: led <= 4'b0001;  // forward
            4'b0011: led <= 4'b0010;  // back
            4'b1110: led <= 4'b0100;  // left
            4'b1101: led <= 4'b1000;  // right
            default: led <= 4'b0000;  // stop / power-on
        endcase

// RGB LEDs (reference colour-cycling effect)
    always @(posedge CLK)
        led4 <= DIV[30:28];

    always @(posedge CLK)
        led5 <= DIV[33:31];

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
                default:      MOTOR <= MOTOR;    // CR, LF, others: ignored
            endcase

    assign ar = MOTOR;

//---- RS232 TX: temperature as two ASCII digits (tens, ones) every ~1.7 s
//     (reference block, unchanged)
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

endmodule
