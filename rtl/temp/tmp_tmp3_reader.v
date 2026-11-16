// ============================================================================
// Module : tmp_tmp3_reader
// Owner  : integrator
// Purpose: I2C master that periodically reads the Pmod TMP3 temperature
//          sensor (7-bit address 0x48). The sensor's pointer register
//          defaults to the temperature register, so each read is:
//            START | 0x48,R | ACK | MSB | master ACK | LSB | master NACK | STOP
//          MSB = integer degrees C (two's complement), LSB bit 7 = 0.5 C.
//          temp_x2_o is the temperature in units of 0.5 C (signed), latched
//          only after a complete, acknowledged read.
// Pins   : scl_o is push-pull. SDA is open drain: the top level must drive
//          the pin low when sda_low_o = 1 and release it otherwise.
// Clock  : clk_i (125 MHz system clock). SCL about 100 kHz, made with a
//          quarter-bit tick, not a derived clock.
// Reset  : rst_n_i, synchronous, active low.
// Origin : adapted from the I2C master written for Lab 3 (D:/FPGA/LAB3).
// ============================================================================
`timescale 1ns / 1ps

module tmp_tmp3_reader #(
    parameter       QTR_CYCLES  = 312,          // quarter SCL period: 125 MHz / (100 kHz * 4)
    parameter       POLL_CYCLES = 31250000,     // 0.25 s between reads
    parameter [6:0] I2C_ADDR    = 7'h48
) (
    input  wire              clk_i,
    input  wire              rst_n_i,
    output wire              scl_o,
    output wire              sda_low_o,          // 1 = pull SDA low
    input  wire              sda_i,
    output reg  signed [8:0] temp_x2_o = 9'sd0,  // 0.5 C per LSB
    output reg               valid_o   = 1'b0,   // 1 = last read was acknowledged
    output reg               update_o  = 1'b0    // one-cycle pulse after every read attempt
);

    localparam [2:0] S_IDLE  = 3'd0;
    localparam [2:0] S_START = 3'd1;
    localparam [2:0] S_ADDR  = 3'd2;
    localparam [2:0] S_AACK  = 3'd3;
    localparam [2:0] S_RD    = 3'd4;
    localparam [2:0] S_MACK  = 3'd5;
    localparam [2:0] S_STOP  = 3'd6;

    reg [1:0]  sda_sync_r = 2'b11;
    reg [15:0] qcnt_r     = 16'd0;
    reg [2:0]  state_r    = S_IDLE;
    reg [1:0]  ph_r       = 2'd0;      // quarter-bit phase
    reg [3:0]  bitc_r     = 4'd0;
    reg        byte_idx_r = 1'b0;      // 0 = MSB byte, 1 = LSB byte
    reg        scl_r      = 1'b1;
    reg        sda_low_r  = 1'b0;
    reg [7:0]  txsh_r     = 8'd0;
    reg [7:0]  rxsh_r     = 8'd0;
    reg [7:0]  b0_r       = 8'd0;
    reg [7:0]  b1_r       = 8'd0;
    reg        ack_n_r    = 1'b0;
    reg        err_r      = 1'b0;
    reg [31:0] pcnt_r     = 32'd0;

    wire sda_in = sda_sync_r[1];
    wire tick   = (qcnt_r == QTR_CYCLES - 1);

    assign scl_o     = scl_r;
    assign sda_low_o = sda_low_r;

    always @(posedge clk_i) begin
        sda_sync_r <= {sda_sync_r[0], sda_i};
        qcnt_r     <= tick ? 16'd0 : qcnt_r + 16'd1;
    end

    always @(posedge clk_i) begin
        if (!rst_n_i) begin
            temp_x2_o  <= 9'sd0;
            valid_o    <= 1'b0;
            update_o   <= 1'b0;
            state_r    <= S_IDLE;
            ph_r       <= 2'd0;
            bitc_r     <= 4'd0;
            byte_idx_r <= 1'b0;
            scl_r      <= 1'b1;
            sda_low_r  <= 1'b0;
            err_r      <= 1'b0;
            pcnt_r     <= 32'd0;
        end else begin
            update_o <= 1'b0;
            if (state_r == S_IDLE) begin
                scl_r     <= 1'b1;
                sda_low_r <= 1'b0;
                if (pcnt_r == POLL_CYCLES - 1) begin
                    pcnt_r  <= 32'd0;
                    state_r <= S_START;
                    ph_r    <= 2'd0;
                    err_r   <= 1'b0;
                end else begin
                    pcnt_r <= pcnt_r + 32'd1;
                end
            end else if (tick) begin
                ph_r <= ph_r + 2'd1;
                case (state_r)
                    S_START: case (ph_r)
                        2'd0: begin scl_r <= 1'b1; sda_low_r <= 1'b0; end
                        2'd1: sda_low_r <= 1'b1;                       // SDA falls while SCL high
                        2'd2: ;
                        2'd3: begin
                            scl_r   <= 1'b0;
                            txsh_r  <= {I2C_ADDR, 1'b1};               // address + READ
                            bitc_r  <= 4'd0;
                            state_r <= S_ADDR;
                        end
                    endcase
                    S_ADDR: case (ph_r)
                        2'd0: begin scl_r <= 1'b0; sda_low_r <= ~txsh_r[7]; end
                        2'd1: scl_r <= 1'b1;
                        2'd2: ;
                        2'd3: begin
                            scl_r  <= 1'b0;
                            txsh_r <= {txsh_r[6:0], 1'b0};
                            if (bitc_r == 4'd7) begin bitc_r <= 4'd0; state_r <= S_AACK; end
                            else bitc_r <= bitc_r + 4'd1;
                        end
                    endcase
                    S_AACK: case (ph_r)
                        2'd0: begin scl_r <= 1'b0; sda_low_r <= 1'b0; end   // release SDA for the ACK
                        2'd1: scl_r <= 1'b1;
                        2'd2: ack_n_r <= sda_in;                            // 0 = ACK
                        2'd3: begin
                            scl_r <= 1'b0;
                            if (ack_n_r) begin
                                err_r   <= 1'b1;
                                state_r <= S_STOP;
                            end else begin
                                bitc_r     <= 4'd0;
                                byte_idx_r <= 1'b0;
                                state_r    <= S_RD;
                            end
                        end
                    endcase
                    S_RD: case (ph_r)
                        2'd0: begin scl_r <= 1'b0; sda_low_r <= 1'b0; end   // slave drives SDA
                        2'd1: scl_r <= 1'b1;
                        2'd2: rxsh_r <= {rxsh_r[6:0], sda_in};
                        2'd3: begin
                            scl_r <= 1'b0;
                            if (bitc_r == 4'd7) begin
                                if (byte_idx_r == 1'b0) b0_r <= rxsh_r;
                                else                    b1_r <= rxsh_r;
                                state_r <= S_MACK;
                            end else begin
                                bitc_r <= bitc_r + 4'd1;
                            end
                        end
                    endcase
                    S_MACK: case (ph_r)
                        2'd0: begin scl_r <= 1'b0; sda_low_r <= ~byte_idx_r; end  // ACK after MSB, NACK after LSB
                        2'd1: scl_r <= 1'b1;
                        2'd2: ;
                        2'd3: begin
                            scl_r <= 1'b0;
                            if (byte_idx_r == 1'b0) begin
                                byte_idx_r <= 1'b1;
                                bitc_r     <= 4'd0;
                                state_r    <= S_RD;
                            end else begin
                                state_r <= S_STOP;
                            end
                        end
                    endcase
                    S_STOP: case (ph_r)
                        2'd0: begin scl_r <= 1'b0; sda_low_r <= 1'b1; end
                        2'd1: scl_r <= 1'b1;
                        2'd2: sda_low_r <= 1'b0;                            // SDA rises while SCL high
                        2'd3: begin
                            state_r  <= S_IDLE;
                            pcnt_r   <= 32'd0;
                            update_o <= 1'b1;
                            valid_o  <= ~err_r;
                            if (!err_r) temp_x2_o <= {b0_r, b1_r[7]};       // latch only a complete read
                        end
                    endcase
                    default: state_r <= S_IDLE;
                endcase
            end
        end
    end

endmodule
