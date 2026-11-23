// -----------------------------------------------------------------------------
// Module : ssd1306_i2c_master
// Owner  : integrator (hardware compatibility test, not part of guardian_top)
// Purpose: Write-only I2C byte master with open-drain outputs.
//          - send_i pulse (while idle) sends data_i. start_i = generate a START
//            before the byte, stop_i = generate a STOP after the byte.
//          - The ACK bit is sampled in the middle of the 9th SCL high phase.
//            On a NACK the master generates a STOP (abort) and reports
//            nack_o = 1 together with done_o, unless ign_nack_i = 1 (then
//            it carries on and still reports nack_o = 1).
//          - scl_low_o / sda_low_o = 1 means "pull the line low", 0 means
//            "release" (the top level turns this into 0 / Z, never a driven 1).
//          - Timing: every bit is 4 quarter periods of QTR_CYC clocks.
//            QTR_CYC = 313 at 125 MHz gives 99.8 kHz SCL, SCL high = SCL low
//            = 5.0 us, START hold = STOP setup = 5.0 us (I2C standard mode).
// Clock  : clk_i 125 MHz
// Reset  : rst_n_i synchronous, active low (releases both lines)
// -----------------------------------------------------------------------------
module ssd1306_i2c_master #(
    parameter QTR_CYC = 313
) (
    input  wire       clk_i,
    input  wire       rst_n_i,
    input  wire       send_i,
    input  wire       start_i,
    input  wire       stop_i,
    input  wire [7:0] data_i,
    input  wire       ign_nack_i,   // 1 = do not abort on NACK (diagnostic)
    input  wire       sda_i,        // raw pin value (synchronized here)
    output reg        busy_o    = 1'b0,
    output reg        done_o    = 1'b0,
    output reg        nack_o    = 1'b0,
    output reg        scl_low_o = 1'b0,
    output reg        sda_low_o = 1'b0
);
    localparam S_IDLE  = 2'd0,
               S_START = 2'd1,
               S_BIT   = 2'd2,
               S_STOP  = 2'd3;

    reg [1:0]  state  = S_IDLE;
    reg [2:0]  step   = 3'd0;     // quarter-period step inside a state
    reg [15:0] qcnt   = 16'd0;
    reg [3:0]  bitn   = 4'd0;     // 0..7 data bits (MSB first), 8 = ACK
    reg [7:0]  sh     = 8'h00;
    reg        stop_f = 1'b0;
    reg        ack_ok = 1'b0;
    reg [1:0]  sda_ff = 2'b11;

    always @(posedge clk_i) sda_ff <= {sda_ff[0], sda_i};
    wire sda_s = sda_ff[1];

    wire tick = (qcnt == QTR_CYC - 1);

    always @(posedge clk_i) begin
        done_o <= 1'b0;
        if (!rst_n_i) begin
            state     <= S_IDLE;
            step      <= 3'd0;
            qcnt      <= 16'd0;
            bitn      <= 4'd0;
            busy_o    <= 1'b0;
            nack_o    <= 1'b0;
            scl_low_o <= 1'b0;
            sda_low_o <= 1'b0;
        end else if (state == S_IDLE) begin
            qcnt <= 16'd0;
            step <= 3'd0;
            if (send_i) begin
                sh     <= data_i;
                stop_f <= stop_i;
                bitn   <= 4'd0;
                busy_o <= 1'b1;
                state  <= start_i ? S_START : S_BIT;
            end
        end else begin
            qcnt <= tick ? 16'd0 : qcnt + 16'd1;
            if (tick) begin
                step <= step + 3'd1;
                case (state)
                    // bus idle (both high) -> SDA low -> hold -> SCL low
                    S_START: begin
                        case (step)
                            3'd0: begin
                                scl_low_o <= 1'b0;
                                sda_low_o <= 1'b1;          // START
                            end
                            3'd2: scl_low_o <= 1'b1;
                            3'd3: begin
                                state <= S_BIT;
                                step  <= 3'd0;
                            end
                            default: ;
                        endcase
                    end
                    // SCL is low on entry. 0: set SDA, 1: SCL high,
                    // 2: sample (ACK), 3: SCL low
                    S_BIT: begin
                        case (step)
                            3'd0: sda_low_o <= (bitn == 4'd8) ? 1'b0 : ~sh[7];
                            3'd1: scl_low_o <= 1'b0;
                            3'd2: if (bitn == 4'd8) ack_ok <= ~sda_s;
                            default: begin                  // step 3
                                scl_low_o <= 1'b1;
                                step      <= 3'd0;
                                if (bitn == 4'd8) begin
                                    if (stop_f || (!ack_ok && !ign_nack_i)) begin
                                        state <= S_STOP;
                                    end else begin
                                        state  <= S_IDLE;
                                        busy_o <= 1'b0;
                                        done_o <= 1'b1;
                                        nack_o <= ~ack_ok;
                                    end
                                end else begin
                                    sh   <= {sh[6:0], 1'b0};
                                    bitn <= bitn + 4'd1;
                                end
                            end
                        endcase
                    end
                    // SCL low on entry. 0: SDA low, 1: SCL high,
                    // 3: SDA high (STOP), 4: bus free time, done
                    default: begin
                        case (step)
                            3'd0: sda_low_o <= 1'b1;
                            3'd1: scl_low_o <= 1'b0;
                            3'd3: sda_low_o <= 1'b0;        // STOP
                            3'd4: begin
                                state  <= S_IDLE;
                                busy_o <= 1'b0;
                                done_o <= 1'b1;
                                nack_o <= ~ack_ok;
                            end
                            default: ;
                        endcase
                    end
                endcase
            end
        end
    end
endmodule
