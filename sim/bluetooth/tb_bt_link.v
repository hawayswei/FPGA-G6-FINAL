// ============================================================================
// Testbench : tb_bt_link
// DUT       : bt_uart_rx + bt_cmd_parser (phone -> FPGA) and
//             bt_msg_tx with bt_uart_tx (FPGA -> phone), 8 clocks per bit
// Checks    : 1. commands E, h165 + CR LF, A, S set mode and height
//             2. out-of-range height (H999), unknown letters, a broken
//                height entry (H1x) are ignored
//             3. a byte with a bad stop bit is dropped
//             4. two requests at once are sent one after the other, each
//                followed by CR LF: "FALL" then "TEMP HIGH"
// Run time  : finishes by itself in under 100 us.
// Expected  : prints "TB PASS".
// ============================================================================
`timescale 1ns / 1ps

module tb_bt_link;

    localparam CPB = 8;              // clocks per bit

    reg  clk_i = 1'b0, rst_n_i = 1'b0;
    reg  phone_tx = 1'b1;            // phone -> FPGA line
    wire [7:0] rx_data;
    wire       rx_valid;
    wire [1:0] mode;
    wire [7:0] height;
    wire       cfg_update;

    reg  [7:0] req = 8'd0;
    wire       fpga_tx, msg_busy;
    wire [7:0] phone_rx_data;
    wire       phone_rx_valid;

    integer errors = 0, updates = 0, n_rx = 0, i;
    reg [8*32-1:0] got = 0;          // text received by the "phone"

    bt_uart_rx #(.CLKS_PER_BIT(CPB)) u_rx (
        .clk_i (clk_i), .rst_n_i (rst_n_i), .rx_i (phone_tx),
        .data_o (rx_data), .valid_o (rx_valid)
    );
    bt_cmd_parser u_parser (
        .clk_i (clk_i), .rst_n_i (rst_n_i),
        .rx_data_i (rx_data), .rx_valid_i (rx_valid),
        .mode_o (mode), .height_o (height), .cfg_update_o (cfg_update)
    );
    bt_msg_tx #(.CLKS_PER_BIT(CPB)) u_msg (
        .clk_i (clk_i), .rst_n_i (rst_n_i), .req_i (req),
        .tx_o (fpga_tx), .busy_o (msg_busy)
    );
    // the "phone" side receiver
    bt_uart_rx #(.CLKS_PER_BIT(CPB)) u_phone_rx (
        .clk_i (clk_i), .rst_n_i (rst_n_i), .rx_i (fpga_tx),
        .data_o (phone_rx_data), .valid_o (phone_rx_valid)
    );

    always #4 clk_i = ~clk_i;

    always @(posedge clk_i) begin
        if (cfg_update) updates = updates + 1;
        if (phone_rx_valid) begin
            got  = {got[8*31-1:0], phone_rx_data};
            n_rx = n_rx + 1;
        end
    end

    task send_byte;
        input [7:0] b;
        input       good_stop;
        integer     k;
        begin
            phone_tx = 1'b0;                       repeat (CPB) @(posedge clk_i);
            for (k = 0; k < 8; k = k + 1) begin
                phone_tx = b[k];                   repeat (CPB) @(posedge clk_i);
            end
            phone_tx = good_stop;                  repeat (CPB) @(posedge clk_i);
            phone_tx = 1'b1;                       repeat (2 * CPB) @(posedge clk_i);
        end
    endtask

    task expect_cfg;
        input [1:0] m;
        input [7:0] h;
        input integer u;
        input [8*16-1:0] what;
        begin
            repeat (4) @(posedge clk_i);
            if (mode !== m || height !== h || updates != u) begin
                errors = errors + 1;
                $display("TB ERROR: %0s: mode=%0d height=%0d updates=%0d, expected %0d %0d %0d",
                         what, mode, height, updates, m, h, u);
            end
        end
    endtask

    initial begin
        #40 rst_n_i = 1'b1;
        repeat (5) @(posedge clk_i);
        expect_cfg(2'd0, 8'd170, 0, "defaults");

        send_byte("E", 1);                              expect_cfg(2'd1, 8'd170, 1, "E");
        send_byte("h", 1); send_byte("1", 1); send_byte("6", 1); send_byte("5", 1);
        send_byte(8'h0D, 1); send_byte(8'h0A, 1);       expect_cfg(2'd1, 8'd165, 2, "h165");
        send_byte("H", 1); send_byte("9", 1); send_byte("9", 1); send_byte("9", 1);
                                                        expect_cfg(2'd1, 8'd165, 2, "H999");
        send_byte("x", 1); send_byte("?", 1);           expect_cfg(2'd1, 8'd165, 2, "unknown");
        send_byte("H", 1); send_byte("1", 1); send_byte("x", 1); send_byte("8", 1); send_byte("0", 1);
                                                        expect_cfg(2'd1, 8'd165, 2, "H1x80");
        send_byte("S", 0);                              expect_cfg(2'd1, 8'd165, 2, "bad stop");
        send_byte("S", 1);                              expect_cfg(2'd2, 8'd165, 3, "S");
        send_byte("a", 1);                              expect_cfg(2'd0, 8'd165, 4, "a");
        send_byte("H", 1); send_byte("1", 1); send_byte("8", 1); send_byte("2", 1);
                                                        expect_cfg(2'd0, 8'd182, 5, "H182");

        // two messages requested in the same cycle
        @(posedge clk_i); req <= 8'b0000_1001;
        @(posedge clk_i); req <= 8'd0;
        repeat (4) @(posedge clk_i);
        while (msg_busy) @(posedge clk_i);
        repeat (3 * CPB) @(posedge clk_i);
        if (n_rx != 17 || got[8*17-1:0] !== {"FALL", 8'h0D, 8'h0A, "TEMP HIGH", 8'h0D, 8'h0A}) begin
            errors = errors + 1;
            $display("TB ERROR: phone received %0d bytes (hex): %h", n_rx, got[8*20-1:0]);
        end

        if (errors == 0) $display("TB PASS: commands parsed, messages sent with CR LF");
        else             $display("TB FAIL: %0d errors", errors);
        $finish;
    end

    initial begin
        #400000;
        $display("TB FAIL: timeout");
        $finish;
    end

endmodule
