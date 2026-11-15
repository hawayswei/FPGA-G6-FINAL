`timescale 1ns / 1ps
// Testbench for CAR (Lab 4 basic): sends UART bytes at 9600 baud and checks
// the motor outputs ar[13:10] and the LED motion indicator.
module CAR_tb;

    reg  CLK  = 1'b0;
    reg  JAIN = 1'b1;
    wire [13:10] ar;
    wire [3:0] led;
    wire [2:0] led4, led5, JA, JB;
    wire JBIN;

    pullup (JBIN);   // I2C line pull-up (no sensor model, value is don't-care)

    CAR dut (.CLK(CLK), .led(led), .led4(led4), .led5(led5),
             .JA(JA), .JAIN(JAIN), .JB(JB), .JBIN(JBIN), .ar(ar));

    always #4 CLK = ~CLK;    // 125 MHz

    localparam real BIT_NS = 1.0e9 / 9600.0;
    integer errors = 0;
    integer i;

    task send_byte(input [7:0] b);
        begin
            JAIN = 1'b0; #(BIT_NS);                    // start bit
            for (i = 0; i < 8; i = i + 1) begin
                JAIN = b[i]; #(BIT_NS);                // LSB first
            end
            JAIN = 1'b1; #(BIT_NS);                    // stop bit
            #(BIT_NS);                                 // idle gap
        end
    endtask

    task check(input [7:0] ch, input [3:0] exp_ar, input [3:0] exp_led);
        begin
            if (ar !== exp_ar || led !== exp_led) begin
                errors = errors + 1;
                $display("FAIL after 0x%h: ar=%b (exp %b) led=%b (exp %b)",
                         ch, ar, exp_ar, led, exp_led);
            end else
                $display("PASS after 0x%h: ar=%b led=%b", ch, ar, led);
        end
    endtask

    initial begin
        #(20000);
        check(8'h00, 4'b0000, 4'b0000);              // power-on: motors off
        send_byte("W"); check("W", 4'b1111, 4'b0001); // forward
        send_byte(8'h0D); check(8'h0D, 4'b1111, 4'b0001); // CR ignored
        send_byte(8'h0A); check(8'h0A, 4'b1111, 4'b0001); // LF ignored
        send_byte("a"); check("a", 4'b1110, 4'b0100); // left (lower case)
        send_byte("D"); check("D", 4'b1101, 4'b1000); // right
        send_byte("S"); check("S", 4'b0011, 4'b0010); // back
        send_byte("x"); check("x", 4'b0011, 4'b0010); // unknown ignored
        send_byte("Q"); check("Q", 4'b1100, 4'b0000); // stop
        send_byte("w"); check("w", 4'b1111, 4'b0001); // forward (lower case)
        if (errors == 0) $display("ALL TESTS PASSED");
        else             $display("TESTS FAILED: %0d", errors);
        $finish;
    end
endmodule
