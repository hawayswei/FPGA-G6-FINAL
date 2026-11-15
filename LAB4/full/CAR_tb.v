`timescale 1ns / 1ps
// Testbench for CAR (Lab 4 full: basic + A1 spin/reverse + C1 alarm): sends UART bytes at 9600 baud and checks
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

    reg [7:0] txb;
    task recv_tx;   // decode one UART byte on JA[2] (FPGA TX)
        begin
            @(negedge JA[2]);
            #(BIT_NS*1.5);
            for (i = 0; i < 8; i = i + 1) begin
                txb[i] = JA[2]; #(BIT_NS);
            end
        end
    endtask

    task set_temp(input [7:0] t);   // emulate a finished TMP3 read
        begin
            force dut.TBUF = {t, 1'b0};
            dut.I2CT = 14'd90;
            #(40000);
            release dut.TBUF;
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
        send_byte("k"); check("k", 4'b0011, 4'b0010); // unknown ignored
        send_byte("Q"); check("Q", 4'b1100, 4'b0000); // stop
        send_byte("w"); check("w", 4'b1111, 4'b0001); // forward (lower case)
        // ---- bonus A1: spin and reverse turns
        send_byte("Z"); check("Z", 4'b1011, 4'b0111); // spin left
        send_byte("x"); check("x", 4'b0111, 4'b1011); // spin right
        send_byte("C"); check("C", 4'b0010, 4'b0110); // reverse-left
        send_byte("v"); check("v", 4'b0001, 4'b1010); // reverse-right
        send_byte("Q"); check("Q", 4'b1100, 4'b0000); // stop
        // ---- bonus C1: over-temperature alarm with hysteresis
        set_temp(8'd25);
        if (dut.HOT !== 1'b0) begin errors = errors + 1; $display("FAIL 25C HOT=%b", dut.HOT); end
        else $display("PASS 25C -> HOT=0");
        set_temp(8'd31);
        if (dut.HOT !== 1'b1 || led4[1:0] !== 2'b00 || led5[1:0] !== 2'b00 ||
            led !== {4{dut.BLINK}} || led4[2] !== dut.BLINK)
            begin errors = errors + 1; $display("FAIL 31C HOT=%b led=%b led4=%b", dut.HOT, led, led4); end
        else $display("PASS 31C -> HOT=1, led=%b led4=%b led5=%b", led, led4, led5);
        send_byte("W"); check("W", 4'b1111, {4{dut.BLINK}}); // driving still works when HOT
        dut.BAUDT = 15'd95;                     // jump just before TX slot 3
        recv_tx;
        if (txb !== 8'h21) begin errors = errors + 1; $display("FAIL TX slot3 = 0x%h", txb); end
        else $display("PASS TX slot3 = '!' (0x%h)", txb);
        set_temp(8'd29);
        if (dut.HOT !== 1'b1) begin errors = errors + 1; $display("FAIL 29C hysteresis"); end
        else $display("PASS 29C -> HOT stays 1 (hysteresis)");
        set_temp(8'd28);
        if (dut.HOT !== 1'b0) begin errors = errors + 1; $display("FAIL 28C HOT=%b", dut.HOT); end
        else $display("PASS 28C -> HOT=0");
        set_temp(8'hFF);                        // no sensor / negative
        if (dut.HOT !== 1'b0) begin errors = errors + 1; $display("FAIL 0xFF HOT"); end
        else $display("PASS 0xFF (no sensor) -> HOT=0");
        if (errors == 0) $display("ALL TESTS PASSED");
        else             $display("TESTS FAILED: %0d", errors);
        $finish;
    end
endmodule
