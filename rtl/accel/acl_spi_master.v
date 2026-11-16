// ============================================================================
// Module : acl_spi_master
// Owner  : integrator
// Purpose: Byte-wide SPI master, mode 0 (CPOL = 0, CPHA = 0), MSB first.
//          Sends tx_data_i and receives rx_data_o at the same time.
//          Chip select is NOT handled here; the caller keeps CS low across
//          as many bytes as the transaction needs.
// Clock  : clk_i (125 MHz system clock). SCLK is a registered output made
//          with a counter, not a derived clock.
//          f_sclk = f_clk / (2 * HALF_DIV); HALF_DIV = 63 -> about 0.99 MHz.
// Reset  : rst_n_i, synchronous, active low.
// Usage  : pulse start_i for one cycle while busy_o = 0. done_o pulses for
//          one cycle when the byte is finished and rx_data_o is valid.
//          start_i may be asserted in the same cycle as done_o.
// ============================================================================
`timescale 1ns / 1ps

module acl_spi_master #(
    parameter HALF_DIV = 63          // clk_i cycles per half SCLK period (>= 4: MISO passes a 2-FF synchronizer)
) (
    input  wire       clk_i,
    input  wire       rst_n_i,
    input  wire       start_i,       // one-cycle pulse: send one byte
    input  wire [7:0] tx_data_i,
    output reg  [7:0] rx_data_o = 8'h00,
    output reg        done_o    = 1'b0,
    output reg        busy_o    = 1'b0,
    output reg        sclk_o    = 1'b0,
    output reg        mosi_o    = 1'b0,
    input  wire       miso_i
);

    reg [15:0] div_cnt_r = 16'd0;
    reg [2:0]  bit_cnt_r = 3'd0;
    reg [7:0]  tx_sh_r   = 8'h00;
    reg [7:0]  rx_sh_r   = 8'h00;
    reg [1:0]  miso_sync_r = 2'b00;  // 2-FF synchronizer for the async input

    wire half_tick = (div_cnt_r == HALF_DIV - 1);

    always @(posedge clk_i) begin
        miso_sync_r <= {miso_sync_r[0], miso_i};
    end

    always @(posedge clk_i) begin
        if (!rst_n_i) begin
            rx_data_o <= 8'h00;
            done_o    <= 1'b0;
            busy_o    <= 1'b0;
            sclk_o    <= 1'b0;
            mosi_o    <= 1'b0;
            div_cnt_r <= 16'd0;
            bit_cnt_r <= 3'd0;
            tx_sh_r   <= 8'h00;
            rx_sh_r   <= 8'h00;
        end else begin
            done_o <= 1'b0;
            if (!busy_o) begin
                if (start_i) begin
                    busy_o    <= 1'b1;
                    tx_sh_r   <= tx_data_i;
                    mosi_o    <= tx_data_i[7];   // MSB is set up before the first rising edge
                    div_cnt_r <= 16'd0;
                    bit_cnt_r <= 3'd0;
                    sclk_o    <= 1'b0;
                end
            end else if (half_tick) begin
                div_cnt_r <= 16'd0;
                if (!sclk_o) begin
                    // Rising edge: the slave's bit has been stable for half a period.
                    sclk_o  <= 1'b1;
                    rx_sh_r <= {rx_sh_r[6:0], miso_sync_r[1]};
                end else begin
                    // Falling edge: shift out the next bit, or finish.
                    sclk_o <= 1'b0;
                    if (bit_cnt_r == 3'd7) begin
                        busy_o    <= 1'b0;
                        done_o    <= 1'b1;
                        rx_data_o <= rx_sh_r;
                    end else begin
                        bit_cnt_r <= bit_cnt_r + 3'd1;
                        tx_sh_r   <= {tx_sh_r[6:0], 1'b0};
                        mosi_o    <= tx_sh_r[6];
                    end
                end
            end else begin
                div_cnt_r <= div_cnt_r + 16'd1;
            end
        end
    end

endmodule
