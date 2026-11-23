// ============================================================================
// Module : acl_adxl362_ctrl
// Owner  : integrator
// Purpose: Controller for the Pmod ACL2 (ADXL362 3-axis accelerometer, SPI).
//          After reset it
//            1. waits for the sensor to power up,
//            2. writes SOFT_RESET (0x1F) = 0x52,
//            3. reads DEVID_AD (0x00) and checks it is 0xAD
//               (wrong ID -> dev_ok_o = 0 and the whole sequence restarts),
//            4. writes FILTER_CTL (0x2C) = FILTER_CTL_VAL (range and rate),
//            5. writes POWER_CTL  (0x2D) = 0x02 (measurement mode),
//            6. every SAMPLE_CYCLES reads XDATA_L..ZDATA_H (0x0E..0x13) in
//               one 8-byte transaction and updates accel_x/y/z_o together.
// Data   : 12-bit two's complement, sign-extended by the sensor to 16 bits.
//          With the default FILTER_CTL_VAL = 0x93 (+-8 g, 100 Hz) one LSB is
//          about 4 mg, so 1 g is about 250.
// Clock  : clk_i (125 MHz system clock, no derived clocks).
// Reset  : rst_n_i, synchronous, active low.
// Notes  : The first few samples after start-up are not settled; users of
//          the data should ignore roughly the first 50 ms.
//          If the sensor loses power while running it falls back to standby
//          and returns zeros; press reset to re-initialize it.
// ============================================================================
`timescale 1ns / 1ps

module acl_adxl362_ctrl #(
    parameter        HALF_DIV       = 63,          // SCLK = 125 MHz / (2*63) ~ 0.99 MHz
    parameter        POWERUP_CYCLES = 2500000,     // 20 ms wait after reset / failed ID
    parameter        RESET_CYCLES   = 1250000,     // 10 ms wait after SOFT_RESET
    parameter        SAMPLE_CYCLES  = 1250000,     // 100 Hz sample rate
    parameter        CS_GAP_CYCLES  = 125,         // 1 us CS setup / hold / high time
    parameter [7:0]  FILTER_CTL_VAL = 8'h93        // +-8 g, half bandwidth, ODR 100 Hz
) (
    input  wire               clk_i,
    input  wire               rst_n_i,
    // SPI pins (to the Pmod ACL2)
    output reg                cs_n_o = 1'b1,
    output wire               sclk_o,
    output wire               mosi_o,
    input  wire               miso_i,
    // Results
    output reg  signed [15:0] accel_x_o    = 16'sd0,
    output reg  signed [15:0] accel_y_o    = 16'sd0,
    output reg  signed [15:0] accel_z_o    = 16'sd0,
    output reg                data_valid_o = 1'b0,  // one-cycle pulse per new sample
    output reg                dev_ok_o     = 1'b0   // 1 = device ID 0xAD was read
);

    // ADXL362 SPI commands and registers
    localparam [7:0] CMD_WRITE      = 8'h0A;
    localparam [7:0] CMD_READ       = 8'h0B;
    localparam [7:0] REG_DEVID_AD   = 8'h00;
    localparam [7:0] REG_XDATA_L    = 8'h0E;
    localparam [7:0] REG_SOFT_RESET = 8'h1F;
    localparam [7:0] REG_FILTER_CTL = 8'h2C;
    localparam [7:0] REG_POWER_CTL  = 8'h2D;
    localparam [7:0] VAL_SOFT_RESET = 8'h52;
    localparam [7:0] VAL_MEASURE    = 8'h02;
    localparam [7:0] VAL_DEVID_AD   = 8'hAD;

    // Which transaction is being performed
    localparam [2:0] STEP_RESET  = 3'd0;
    localparam [2:0] STEP_ID     = 3'd1;
    localparam [2:0] STEP_FILTER = 3'd2;
    localparam [2:0] STEP_POWER  = 3'd3;
    localparam [2:0] STEP_READ   = 3'd4;

    // Transaction engine states
    localparam [2:0] ST_WAIT  = 3'd0;   // CS high, wait for timer (or sample tick)
    localparam [2:0] ST_SETUP = 3'd1;   // CS low, wait CS setup time
    localparam [2:0] ST_SEND  = 3'd2;   // start one byte
    localparam [2:0] ST_BUSY  = 3'd3;   // wait for the byte
    localparam [2:0] ST_HOLD  = 3'd4;   // CS hold time after the last byte
    localparam [2:0] ST_END   = 3'd5;   // CS high, use the result, pick next step

    reg [2:0]  state_r = ST_WAIT;
    reg [2:0]  step_r  = STEP_RESET;
    reg [2:0]  idx_r   = 3'd0;          // byte index inside the transaction
    reg [31:0] timer_r = POWERUP_CYCLES;
    reg [31:0] sample_cnt_r  = 32'd0;
    reg        sample_pend_r = 1'b0;    // a sample period has elapsed
    reg [7:0]  rx_r [0:5];              // XL XH YL YH ZL ZH
    reg [7:0]  id_r = 8'h00;

    reg        spi_start_r = 1'b0;
    reg  [7:0] tx_byte;
    wire [7:0] spi_rx;
    wire       spi_done;
    wire       spi_busy;

    wire [2:0] last_idx = (step_r == STEP_READ) ? 3'd7 : 3'd2;

    acl_spi_master #(.HALF_DIV(HALF_DIV)) u_spi (
        .clk_i     (clk_i),
        .rst_n_i   (rst_n_i),
        .start_i   (spi_start_r),
        .tx_data_i (tx_byte),
        .rx_data_o (spi_rx),
        .done_o    (spi_done),
        .busy_o    (spi_busy),
        .sclk_o    (sclk_o),
        .mosi_o    (mosi_o),
        .miso_i    (miso_i)
    );

    // Byte to send: command, register address, then data (or dummy 0x00 on reads)
    always @(*) begin
        tx_byte = 8'h00;
        case (idx_r)
            3'd0: tx_byte = (step_r == STEP_ID || step_r == STEP_READ) ? CMD_READ : CMD_WRITE;
            3'd1: begin
                case (step_r)
                    STEP_RESET:  tx_byte = REG_SOFT_RESET;
                    STEP_ID:     tx_byte = REG_DEVID_AD;
                    STEP_FILTER: tx_byte = REG_FILTER_CTL;
                    STEP_POWER:  tx_byte = REG_POWER_CTL;
                    default:     tx_byte = REG_XDATA_L;
                endcase
            end
            3'd2: begin
                case (step_r)
                    STEP_RESET:  tx_byte = VAL_SOFT_RESET;
                    STEP_FILTER: tx_byte = FILTER_CTL_VAL;
                    STEP_POWER:  tx_byte = VAL_MEASURE;
                    default:     tx_byte = 8'h00;
                endcase
            end
            default: tx_byte = 8'h00;
        endcase
    end

    integer i;
    initial begin
        for (i = 0; i < 6; i = i + 1) rx_r[i] = 8'h00;
    end

    always @(posedge clk_i) begin
        if (!rst_n_i) begin
            cs_n_o        <= 1'b1;
            accel_x_o     <= 16'sd0;
            accel_y_o     <= 16'sd0;
            accel_z_o     <= 16'sd0;
            data_valid_o  <= 1'b0;
            dev_ok_o      <= 1'b0;
            state_r       <= ST_WAIT;
            step_r        <= STEP_RESET;
            idx_r         <= 3'd0;
            timer_r       <= POWERUP_CYCLES;
            sample_cnt_r  <= 32'd0;
            sample_pend_r <= 1'b0;
            spi_start_r   <= 1'b0;
            id_r          <= 8'h00;
        end else begin
            data_valid_o <= 1'b0;
            spi_start_r  <= 1'b0;

            // Free-running sample period, independent of transaction length
            if (sample_cnt_r == SAMPLE_CYCLES - 1) begin
                sample_cnt_r  <= 32'd0;
                sample_pend_r <= 1'b1;
            end else begin
                sample_cnt_r <= sample_cnt_r + 32'd1;
            end

            case (state_r)
                ST_WAIT: begin
                    cs_n_o <= 1'b1;
                    if (timer_r != 32'd0) begin
                        timer_r <= timer_r - 32'd1;
                    end else if (step_r != STEP_READ || sample_pend_r) begin
                        sample_pend_r <= 1'b0;
                        cs_n_o        <= 1'b0;
                        idx_r         <= 3'd0;
                        timer_r       <= CS_GAP_CYCLES;
                        state_r       <= ST_SETUP;
                    end
                end

                ST_SETUP: begin
                    if (timer_r != 32'd0) timer_r <= timer_r - 32'd1;
                    else                  state_r <= ST_SEND;
                end

                ST_SEND: begin
                    spi_start_r <= 1'b1;
                    state_r     <= ST_BUSY;
                end

                ST_BUSY: begin
                    if (spi_done) begin
                        if (step_r == STEP_ID && idx_r == 3'd2)
                            id_r <= spi_rx;
                        if (step_r == STEP_READ && idx_r >= 3'd2)
                            rx_r[idx_r - 3'd2] <= spi_rx;
                        if (idx_r == last_idx) begin
                            timer_r <= CS_GAP_CYCLES;
                            state_r <= ST_HOLD;
                        end else begin
                            idx_r   <= idx_r + 3'd1;
                            state_r <= ST_SEND;
                        end
                    end
                end

                ST_HOLD: begin
                    if (timer_r != 32'd0) timer_r <= timer_r - 32'd1;
                    else begin
                        cs_n_o  <= 1'b1;
                        state_r <= ST_END;
                    end
                end

                ST_END: begin
                    state_r <= ST_WAIT;
                    timer_r <= CS_GAP_CYCLES;          // minimum CS high time
                    case (step_r)
                        STEP_RESET: begin
                            step_r  <= STEP_ID;
                            timer_r <= RESET_CYCLES;
                        end
                        STEP_ID: begin
                            if (id_r == VAL_DEVID_AD) begin
                                dev_ok_o <= 1'b1;
                                step_r   <= STEP_FILTER;
                            end else begin
                                dev_ok_o <= 1'b0;      // no sensor or bad wiring: retry
                                step_r   <= STEP_RESET;
                                timer_r  <= POWERUP_CYCLES;
                            end
                        end
                        STEP_FILTER: step_r <= STEP_POWER;
                        STEP_POWER:  step_r <= STEP_READ;
                        default: begin                 // STEP_READ: publish all axes together
                            accel_x_o    <= {rx_r[1], rx_r[0]};
                            accel_y_o    <= {rx_r[3], rx_r[2]};
                            accel_z_o    <= {rx_r[5], rx_r[4]};
                            data_valid_o <= 1'b1;
                        end
                    endcase
                end

                default: state_r <= ST_WAIT;
            endcase
        end
    end

endmodule
