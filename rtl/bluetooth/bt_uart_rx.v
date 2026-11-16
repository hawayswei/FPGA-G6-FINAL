// ============================================================================
// Module : bt_uart_rx
// Owner  : integrator
// Purpose: UART receiver, 8N1. Default 9600 baud for the course Bluetooth
//          module. 2-FF synchronizer, start bit re-checked at mid-bit, data
//          sampled at mid-bit, stop bit checked. valid_o pulses for one cycle
//          only for a complete byte with a correct stop bit.
// Clock  : clk_i (125 MHz system clock).
// Reset  : rst_n_i, synchronous, active low.
// ============================================================================
`timescale 1ns / 1ps

module bt_uart_rx #(
    parameter CLKS_PER_BIT = 13021      // 125 MHz / 9600 baud
) (
    input  wire       clk_i,
    input  wire       rst_n_i,
    input  wire       rx_i,             // serial input, idle high (asynchronous)
    output reg  [7:0] data_o  = 8'h00,
    output reg        valid_o = 1'b0
);

    localparam [1:0] ST_IDLE  = 2'd0;
    localparam [1:0] ST_START = 2'd1;
    localparam [1:0] ST_DATA  = 2'd2;
    localparam [1:0] ST_STOP  = 2'd3;

    reg [1:0]  sync_r  = 2'b11;
    reg [1:0]  state_r = ST_IDLE;
    reg [15:0] cnt_r   = 16'd0;
    reg [2:0]  bit_r   = 3'd0;
    reg [7:0]  sh_r    = 8'h00;

    wire rx_s = sync_r[1];

    always @(posedge clk_i) begin
        sync_r <= {sync_r[0], rx_i};
    end

    always @(posedge clk_i) begin
        if (!rst_n_i) begin
            data_o  <= 8'h00;
            valid_o <= 1'b0;
            state_r <= ST_IDLE;
            cnt_r   <= 16'd0;
            bit_r   <= 3'd0;
            sh_r    <= 8'h00;
        end else begin
            valid_o <= 1'b0;
            case (state_r)
                ST_IDLE: begin
                    cnt_r <= 16'd0;
                    if (!rx_s) state_r <= ST_START;
                end
                ST_START: begin                       // wait to the middle of the start bit
                    if (cnt_r == (CLKS_PER_BIT / 2) - 1) begin
                        cnt_r   <= 16'd0;
                        bit_r   <= 3'd0;
                        state_r <= rx_s ? ST_IDLE : ST_DATA;   // glitch -> ignore
                    end else begin
                        cnt_r <= cnt_r + 16'd1;
                    end
                end
                ST_DATA: begin                        // one bit time later = middle of each data bit
                    if (cnt_r == CLKS_PER_BIT - 1) begin
                        cnt_r <= 16'd0;
                        sh_r  <= {rx_s, sh_r[7:1]};   // LSB first
                        if (bit_r == 3'd7) state_r <= ST_STOP;
                        else               bit_r   <= bit_r + 3'd1;
                    end else begin
                        cnt_r <= cnt_r + 16'd1;
                    end
                end
                ST_STOP: begin
                    if (cnt_r == CLKS_PER_BIT - 1) begin
                        cnt_r   <= 16'd0;
                        state_r <= ST_IDLE;
                        if (rx_s) begin               // valid stop bit
                            data_o  <= sh_r;
                            valid_o <= 1'b1;
                        end
                    end else begin
                        cnt_r <= cnt_r + 16'd1;
                    end
                end
                default: state_r <= ST_IDLE;
            endcase
        end
    end

endmodule
