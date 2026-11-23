// -----------------------------------------------------------------------------
// Module : lcd1602_driver
// Owner  : integrator (hardware compatibility test, not part of guardian_top)
// Purpose: Write one byte (or one nibble) to an HD44780-compatible 1602A
//          character LCD in 4-bit mode. Write-only: the LCD RW pin must be
//          wired to GND, so the LCD never drives the data lines.
// Clock  : clk_i (125 MHz)
// Reset  : rst_n_i, synchronous, active low
// Timing : each nibble = setup (PHASE_CYC) -> E high (PHASE_CYC) -> hold
//          (PHASE_CYC). After the last nibble the driver waits wait_cyc_i
//          clock cycles (command execution time) and then pulses done_o.
// -----------------------------------------------------------------------------
module lcd1602_driver #(
    parameter PHASE_CYC = 1250            // 10 us at 125 MHz
) (
    input  wire        clk_i,
    input  wire        rst_n_i,
    input  wire        start_i,           // one-clock strobe, only when !busy_o
    input  wire        rs_i,              // 0 = command, 1 = data
    input  wire [7:0]  data_i,
    input  wire        nib_only_i,        // 1 = send only data_i[7:4]
    input  wire [23:0] wait_cyc_i,        // wait after the byte
    output reg         busy_o,
    output reg         done_o,
    output reg         lcd_rs_o,
    output reg         lcd_e_o,
    output reg  [3:0]  lcd_d_o
);
    localparam S_IDLE  = 3'd0,
               S_SETUP = 3'd1,
               S_EHIGH = 3'd2,
               S_HOLD  = 3'd3,
               S_WAIT  = 3'd4;

    reg [2:0]  state   = S_IDLE;
    reg [23:0] cnt     = 24'd0;
    reg [3:0]  low_nib = 4'd0;
    reg        second  = 1'b0;            // 1 = low nibble still to send
    reg [23:0] wait_r  = 24'd0;

    initial begin
        busy_o   = 1'b0;
        done_o   = 1'b0;
        lcd_rs_o = 1'b0;
        lcd_e_o  = 1'b0;
        lcd_d_o  = 4'd0;
    end

    always @(posedge clk_i) begin
        done_o <= 1'b0;
        if (!rst_n_i) begin
            state   <= S_IDLE;
            cnt     <= 24'd0;
            busy_o  <= 1'b0;
            lcd_e_o <= 1'b0;
            second  <= 1'b0;
        end else begin
            case (state)
                S_IDLE: begin
                    lcd_e_o <= 1'b0;
                    if (start_i) begin
                        busy_o   <= 1'b1;
                        lcd_rs_o <= rs_i;
                        lcd_d_o  <= data_i[7:4];
                        low_nib  <= data_i[3:0];
                        second   <= ~nib_only_i;
                        wait_r   <= wait_cyc_i;
                        cnt      <= 24'd0;
                        state    <= S_SETUP;
                    end
                end
                S_SETUP: begin
                    if (cnt == PHASE_CYC - 1) begin
                        cnt     <= 24'd0;
                        lcd_e_o <= 1'b1;
                        state   <= S_EHIGH;
                    end else begin
                        cnt <= cnt + 24'd1;
                    end
                end
                S_EHIGH: begin
                    if (cnt == PHASE_CYC - 1) begin
                        cnt     <= 24'd0;
                        lcd_e_o <= 1'b0;      // LCD latches on this falling edge
                        state   <= S_HOLD;
                    end else begin
                        cnt <= cnt + 24'd1;
                    end
                end
                S_HOLD: begin
                    if (cnt == PHASE_CYC - 1) begin
                        cnt <= 24'd0;
                        if (second) begin
                            second  <= 1'b0;
                            lcd_d_o <= low_nib;
                            state   <= S_SETUP;
                        end else begin
                            state <= S_WAIT;
                        end
                    end else begin
                        cnt <= cnt + 24'd1;
                    end
                end
                S_WAIT: begin
                    if (cnt >= wait_r) begin
                        cnt    <= 24'd0;
                        busy_o <= 1'b0;
                        done_o <= 1'b1;
                        state  <= S_IDLE;
                    end else begin
                        cnt <= cnt + 24'd1;
                    end
                end
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
