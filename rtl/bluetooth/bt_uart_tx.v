// ============================================================================
// Module : bt_uart_tx
// Owner  : integrator
// Purpose: UART transmitter, 8N1. Default 9600 baud for the course Bluetooth
//          module. Pulse start_i for one cycle while busy_o = 0.
// Clock  : clk_i (125 MHz system clock).
// Reset  : rst_n_i, synchronous, active low.
// ============================================================================
`timescale 1ns / 1ps

module bt_uart_tx #(
    parameter CLKS_PER_BIT = 13021      // 125 MHz / 9600 baud
) (
    input  wire       clk_i,
    input  wire       rst_n_i,
    input  wire       start_i,
    input  wire [7:0] data_i,
    output reg        tx_o   = 1'b1,    // serial output, idle high
    output reg        busy_o = 1'b0
);

    reg [15:0] cnt_r = 16'd0;
    reg [3:0]  bit_r = 4'd0;
    reg [9:0]  sh_r  = 10'h3FF;         // {stop, data[7:0], start}

    always @(posedge clk_i) begin
        if (!rst_n_i) begin
            tx_o   <= 1'b1;
            busy_o <= 1'b0;
            cnt_r  <= 16'd0;
            bit_r  <= 4'd0;
            sh_r   <= 10'h3FF;
        end else if (!busy_o) begin
            tx_o <= 1'b1;
            if (start_i) begin
                busy_o <= 1'b1;
                sh_r   <= {1'b1, data_i, 1'b0};
                cnt_r  <= 16'd0;
                bit_r  <= 4'd0;
                tx_o   <= 1'b0;                       // start bit
            end
        end else if (cnt_r == CLKS_PER_BIT - 1) begin
            cnt_r <= 16'd0;
            if (bit_r == 4'd9) begin
                busy_o <= 1'b0;                       // stop bit finished
                tx_o   <= 1'b1;
            end else begin
                bit_r <= bit_r + 4'd1;
                sh_r  <= {1'b1, sh_r[9:1]};
                tx_o  <= sh_r[1];
            end
        end else begin
            cnt_r <= cnt_r + 16'd1;
        end
    end

endmodule
